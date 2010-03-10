module DataMiner
  class Import
    attr_accessor :configuration, :position_in_run, :options, :table, :errata
    attr_accessor :description
    delegate :resource, :to => :configuration
    delegate :unique_indices, :to => :configuration
    
    def initialize(configuration, position_in_run, description, options = {}, &block)
      @configuration = configuration
      @position_in_run = position_in_run
      @description = description
      @options = options
      yield self if block_given? # pull in attributes
      @errata = Errata.new(:url => options[:errata], :klass => resource) if options[:errata]
      @table = RemoteTable.new(options.slice(:url, :filename, :post_data, :format, :skip, :cut, :schema, :schema_name, :trap, :select, :reject, :sheet, :delimiter, :headers, :transform, :crop))
    end

    def inspect
      "Import(#{resource}) position #{position_in_run} (#{description})"
    end

    def attributes
      configuration.attributes.reject { |k, v| !v.stored_by? self }
    end
    
    def stores?(attr_name)
      configuration.attributes[attr_name].andand.stored_by? self
    end

    def store(attr_name, attr_options = {})
      configuration.attributes[attr_name] ||= Attribute.new(resource, attr_name)
      configuration.attributes[attr_name].options_for_import[self] = attr_options
    end

    def run(run)
      table.each_row do |row|
        if errata
          next if errata.rejects?(row)
          errata.correct!(row)
        end

        unifying_values = unique_indices.map do |attr_name|
          [ attributes[attr_name].value_from_row(self, row) ]
        end
        
        record_set = WilliamJamesCartesianProduct.cart_prod(*unifying_values).map do |combination|
          next if combination.include?(nil)
          resource.send "find_or_initialize_by_#{unique_indices.to_a.join('_and_')}", *combination
        end.flatten

        Array.wrap(record_set).each do |record|
          changes = attributes.values.map { |attr| attr.set_record_from_row self, record, row }
          record.data_miner_touch_count ||= 0
          if changes.any?
            record.data_miner_touch_count += 1
            record.data_miner_last_run = run
          end
          record.save!
        end
      end
      DataMiner.logger.info "performed #{inspect}"
    end
  end
end
