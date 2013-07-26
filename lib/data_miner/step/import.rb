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

      # Description of what this step does.
      # @return [String]
      attr_reader :description

      # Max number of rows to import.
      # @return [Numeric]
      attr_reader :limit

      # Number from zero to one representing what percentage of rows to skip. Defaults to 0, of course :)
      # @return [Numeric]
      attr_reader :random_skip

      # @private
      attr_reader :listeners

      # @private
      def initialize(script, description, settings, &blk)
        settings = settings.stringify_keys
        if settings.has_key?('table')
          raise ::ArgumentError, %{[data_miner] :table is no longer an allowed setting.}
        end
        if (errata_settings = settings['errata']) and not errata_settings.is_a?(::Hash)
          raise ::ArgumentError, %{[data_miner] :errata must be a hash of initialization settings to Errata}
        end
        @script = script
        @attributes = ::ActiveSupport::OrderedHash.new
        @validate_query = !!settings['validate']
        @description = description
        if settings.has_key? 'errata'
          errata_settings = settings['errata'].stringify_keys
          errata_settings['responder'] ||= model
          settings['errata'] = errata_settings
        end
        @table_settings = settings.dup
        @table_settings['streaming'] = true
        @table_mutex = ::Mutex.new
        @limit = settings.fetch 'limit', (1.0/0)
        @random_skip = settings['random_skip']
        @listeners = []
        instance_eval(&blk)
      end

      # Store data into a model column.
      #
      # @see DataMiner::Attribute The actual Attribute class.
      #
      # @param [String] attr_name The name of the local model column.
      # @param [optional, Hash] attr_options Options that will be passed to +DataMiner::Attribute.new+
      # @option attr_options [*] anything Any option for +DataMiner::Attribute+.
      #
      # @return [nil]
      def store(attr_name, attr_options = {}, &blk)
        attr_name = attr_name.to_s
        if attributes.has_key? attr_name
          raise "You should only call store or key once for #{model.name}##{attr_name}"
        end
        attributes[attr_name] = DataMiner::Attribute.new self, attr_name, attr_options, &blk
      end

      # Store data into a model column AND use it as the key.
      #
      # @see DataMiner::Attribute The actual Attribute class.
      #
      # Enables idempotency. In other words, you can run the data miner script multiple times, get updated data, and not get duplicate rows.
      #
      # @param [String] attr_name The name of the local model column.
      # @param [optional, Hash] attr_options Options that will be passed to +DataMiner::Attribute.new+
      # @option attr_options [*] anything Any option for +DataMiner::Attribute+.
      #
      # @return [nil]
      def key(attr_name, attr_options = {})
        attr_name = attr_name.to_s
        if attributes.has_key? attr_name
          raise "You should only call store or key once for #{model.name}##{attr_name}"
        end
        @key = attr_name
        store attr_name, attr_options
      end

      # @private
      def start
        upsert_enabled? ? save_with_upsert : save_with_find_or_initialize
        refresh
        nil
      end

      # @private
      # Whether to run ActiveRecord validations. Slows things down because Upsert isn't used.
      def validate?
        @validate_query == true
      end

      def register(step)
        if step.target?(self)
          listeners << step
        end
      end

      private

      def upsert_enabled?
        (not validate?) and (storing_primary_key? or table_has_autoincrementing_primary_key?)
      end

      def count_every
        @count_every ||= ENV.fetch('DATA_MINER_COUNT_EVERY', -1).to_i
      end

      def save_with_upsert
        c = model.connection_pool.checkout
        attrs_except_key = attributes.except(@key).values
        count = 0
        Upsert.stream(c, model.table_name) do |upsert|
          table.each do |row|
            next if random_skip and random_skip > Kernel.rand
            $stderr.puts "#{count}..." if count_every > 0 and count % count_every == 0
            break if count > limit
            count += 1
            selector = @key ? { @key => attributes[@key].read(row) } : { model.primary_key => nil }
            document = attrs_except_key.inject({}) do |memo, attr|
              attr.updates(row).each do |k, v|
                case memo[k]
                when ::Hash
                  memo[k] = memo[k].merge v
                else
                  memo[k] = v
                end
              end
              memo
            end
            upsert.row selector, document
            listeners.select! do |listener|
              listener.notify self, count
            end
          end
        end
        model.connection_pool.checkin c
      end

      def save_with_find_or_initialize
        count = 0
        table.each do |row|
          next if random_skip and random_skip > Kernel.rand
          $stderr.puts "#{count}..." if count_every > 0 and count % count_every == 0
          break if count > limit
          count += 1
          record = @key ? model.send("find_or_initialize_by_#{@key}", attributes[@key].read(row)) : model.new
          attributes.each { |_, attr| attr.set_from_row record, row }
          record.save!
          listeners.select! do |listener|
            listener.notify self, count
          end
        end
      end

      def table_has_autoincrementing_primary_key?
        return @table_has_autoincrementing_primary_key_query if defined?(@table_has_autoincrementing_primary_key_query)
        c = model.connection_pool.checkout
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
        model.connection_pool.checkin c
        @table_has_autoincrementing_primary_key_query = answer
      end

      def storing_primary_key?
        return @storing_primary_key_query if defined?(@storing_primary_key_query)
        @storing_primary_key_query = model.primary_key && attributes.has_key?(model.primary_key)
      end

      def table
        @table || @table_mutex.synchronize do
          @table ||= ::RemoteTable.new(@table_settings)
        end
      end

      def refresh
        @table = nil
        nil
      end
    end
  end
end
