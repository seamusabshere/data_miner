require 'errata'
require 'remote_table'
require 'upsert'

class DataMiner
  class Step
    # A step that imports data from a remote source.
    #
    # Create these by calling +import+ inside a +data_miner+ block.
    #
    # @see DataMiner::ActiveRecordClassMethods#data_miner Overview of how to define data miner scripts inside of ActiveRecord models.
    # @see DataMiner::Script#import Creating an import step by calling DataMiner::Script#import from inside a data miner script
    # @see DataMiner::Attribute The Attribute class, which maps local columns and remote data fields from within an import step
    class Import < Step
      # The mappings of local columns to remote data source fields.
      # @return [Array<DataMiner::Attribute>]
      attr_reader :attributes

      # @private
      attr_reader :script

      # Description of what this step does.
      # @return [String]
      attr_reader :description
      
      # @private
      def initialize(script, description, table_and_errata_settings, &blk)
        table_and_errata_settings = table_and_errata_settings.symbolize_keys
        if table_and_errata_settings.has_key?(:table)
          raise ::ArgumentError, %{[data_miner] :table is no longer an allowed setting.}
        end
        if (errata_settings = table_and_errata_settings[:errata]) and not errata_settings.is_a?(::Hash)
          raise ::ArgumentError, %{[data_miner] :errata must be a hash of initialization settings to Errata}
        end
        @script = script
        @attributes = ::ActiveSupport::OrderedHash.new
        @description = description
        if table_and_errata_settings.has_key? :errata
          errata_settings = table_and_errata_settings[:errata].symbolize_keys
          errata_settings[:responder] ||= model
          table_and_errata_settings[:errata] = errata_settings
        end
        @table_settings = table_and_errata_settings.dup
        @table_settings[:streaming] = true
        @table_mutex = ::Mutex.new
        instance_eval(&blk)
      end

      # Store data into a model column.
      #
      # @see DataMiner::Attribute The actual Attribute class.
      #
      # @param [Symbol] attr_name The name of the local model column.
      # @param [optional, Hash] attr_options Options that will be passed to +DataMiner::Attribute.new+
      # @option attr_options [*] anything Any option for +DataMiner::Attribute+.
      #
      # @return [nil]
      def store(attr_name, attr_options = {})
        attr_name = attr_name.to_sym
        if attributes.has_key? attr_name
          raise "You should only call store or key once for #{model.name}##{attr_name}"
        end
        attributes[attr_name] = DataMiner::Attribute.new self, attr_name, attr_options
      end

      # Store data into a model column AND use it as the key.
      #
      # @see DataMiner::Attribute The actual Attribute class.
      #
      # Enables idempotency. In other words, you can run the data miner script multiple times, get updated data, and not get duplicate rows.
      #
      # @param [Symbol] attr_name The name of the local model column.
      # @param [optional, Hash] attr_options Options that will be passed to +DataMiner::Attribute.new+
      # @option attr_options [*] anything Any option for +DataMiner::Attribute+.
      #
      # @return [nil]
      def key(attr_name, attr_options = {})
        attr_name = attr_name.to_sym
        if attributes.has_key? attr_name
          raise "You should only call store or key once for #{model.name}##{attr_name}"
        end
        @key = attr_name
        store attr_name, attr_options
      end

      # @private
      def start
        if storing_primary_key? or table_has_autoincrementing_primary_key?
          c = ActiveRecord::Base.connection_pool.checkout
          Upsert.stream(c, model.table_name) do |upsert|
            table.each do |row|
              selector = { @key => attributes[@key].read(row) }
              document = attributes.except(@key).inject({}) do |memo, (_, attr)|
                memo.merge! attr.updates(row)
                memo
              end
              upsert.row selector, document
            end
          end
          ActiveRecord::Base.connection_pool.checkin c
        else
          table.each do |row|
            record = model.send "find_or_initialize_by_#{@key}", attributes[@key].read(row)
            attributes.each { |_, attr| attr.set_from_row record, row }
            record.save!
          end
        end
        refresh
        nil
      end

      private

      def table_has_autoincrementing_primary_key?
        return @table_has_autoincrementing_primary_key_query.first if @table_has_autoincrementing_primary_key_query.is_a?(Array)
        c = ActiveRecord::Base.connection_pool.checkout
        answer = if (pk = model.primary_key) and model.columns_hash[pk].type == :integer
          case c.adapter_name
          when /mysql/i
            extra = c.select_value %{SELECT EXTRA FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = #{c.quote(c.current_database)} AND TABLE_NAME = #{c.quote(model.table_name)} AND COLUMN_NAME = #{c.quote(pk)}}
            extra.to_s.include?('auto_increment')
          when /postgres/i
            column_default = c.select_value %{SELECT COLUMN_DEFAULT FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = #{c.quote(model.table_name)} AND COLUMN_NAME = #{c.quote(pk)}}
            column_default.to_s.include?('nextval')
          when /sqlite/i
            # FIXME doesn't work
            # row = c.select_rows("PRAGMA table_info(#{model.quoted_table_name})").detect { |r| r[1] == pk }
            # row[2] == 'INTEGER' and row[3] == 1 and row[5] == 1
            true
          end
        end
        ActiveRecord::Base.connection_pool.checkin c
        @table_has_autoincrementing_primary_key_query = [answer]
        answer
      end

      def storing_primary_key?
        return @storing_primary_key_query.first if @storing_primary_key_query.is_a?(Array)
        @storing_primary_key_query = [attributes.has_key?(model.primary_key.to_sym)]
        @storing_primary_key_query.first
      end

      def table
        @table || @table_mutex.synchronize do
          @table ||= ::RemoteTable.new(@table_settings)
        end
      end

      def refresh
        @table = nil
        attributes.each { |_, attr| attr.refresh }
        nil
      end
    end
  end
end
