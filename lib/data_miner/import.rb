module DataMiner
  class Import
    include Blockenspiel::DSL
    
    attr_reader :attributes
    attr_accessor :configuration, :position_in_run, :table
    attr_accessor :description
    delegate :resource, :to => :configuration
    
    def initialize(configuration, position_in_run, description, table_options = {})
      table_options.symbolize_keys!

      @attributes = ActiveSupport::OrderedHash.new
      @configuration = configuration
      @position_in_run = position_in_run
      @description = description
      if table_options[:table].present?
        DataMiner.log_or_raise "You should specify :table or :url, but not both" if table_options[:url].present?
        @table = table_options[:table]
      else
        @table = RemoteTable.new table_options
      end
    end

    def inspect
      "Import(#{resource}) position #{position_in_run} (#{description})"
    end

    def stores?(attr_name)
      attributes.has_key? attr_name
    end
    
    def store(attr_name, attr_options = {})
      DataMiner.log_or_raise "You should only call store or key once for #{resource.name}##{attr_name}" if attributes.has_key? attr_name
      attributes[attr_name] = Attribute.new self, attr_name, attr_options
    end
    
    def key(attr_name, attr_options = {})
      DataMiner.log_or_raise "You should only call store or key once for #{resource.name}##{attr_name}" if attributes.has_key? attr_name
      @key = attr_name
      store attr_name, attr_options
    end

    def run(run)
      begin; ActiveRecord::Base.connection.execute("SET NAMES 'utf8'"); rescue; end
      
      increment_counter = resource.column_names.include?('data_miner_touch_count')
      log_run = resource.column_names.include?('data_miner_last_run_id')
      test_counter = 0

      table.each_row do |row|
        if ENV['DUMP'] == 'true'
          raise "[data_miner gem] Stopping after 5 rows because TEST=true" if test_counter > 5
          test_counter += 1
          DataMiner.log_info %{Row #{test_counter}
IN:  #{row.inspect}
OUT: #{attributes.inject(Hash.new) { |memo, v| attr_name, attr = v; memo[attr_name] = attr.value_from_row(row); memo }.inspect}
          }
        end
      
        record = resource.send "find_or_initialize_by_#{@key}", attributes[@key].value_from_row(row)
        changes = attributes.map { |_, attr| attr.set_record_from_row record, row }
        if changes.any?
          record.increment :data_miner_touch_count if increment_counter
          record.data_miner_last_run = run if log_run
        end
        record.save!
      end
      DataMiner.log_info "performed #{inspect}"
    end
  end
end
