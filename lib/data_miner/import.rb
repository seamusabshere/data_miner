module DataMiner
  class Import
    include Blockenspiel::DSL
    
    attr_reader :attributes
    attr_accessor :configuration, :position_in_run, :options, :table, :errata
    attr_accessor :description
    delegate :resource, :to => :configuration
    
    def initialize(configuration, position_in_run, description, options = {})
      options.symbolize_keys!
      @options = options

      @attributes = ActiveSupport::OrderedHash.new
      @configuration = configuration
      @position_in_run = position_in_run
      @description = description
      @errata = Errata.new(:url => options[:errata], :klass => resource) if options[:errata]
      @table = RemoteTable.new(options.slice(:url, :filename, :form_data, :format, :skip, :cut, :schema, :schema_name, :trap, :select, :reject, :sheet, :delimiter, :headers, :transform, :crop, :encoding, :compression, :glob))
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
      table.each_row do |row|
        if errata
          next if errata.rejects?(row)
          errata.correct!(row)
        end
        
        record = resource.send "find_or_initialize_by_#{@key}", attributes[@key].value_from_row(row)
        changes = attributes.map { |_, attr| attr.set_record_from_row record, row }
        record.data_miner_touch_count ||= 0
        if changes.any?
          record.data_miner_touch_count += 1
          record.data_miner_last_run = run
        end
        record.save!
      end
      DataMiner.log_info "performed #{inspect}"
    end
  end
end
