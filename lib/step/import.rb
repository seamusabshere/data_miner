module DataMiner
  class Step
    class Import < Step
      attr_accessor :table, :errata
      
      def initialize(configuration, number, options = {}, &block)
        super
        @errata = Errata.new(:url => options[:errata], :klass => klass) if options[:errata]
        @table = RemoteTable.new(options.slice(:url, :filename, :post_data, :format, :skip, :cut, :schema, :schema_name, :trap, :select, :reject, :sheet, :delimiter, :headers, :transform, :crop))
      end
      
      def signature
        "#{super} #{options[:url]}"
      end

      def perform
        ActiveRecord::Base.connection.execute("TRUNCATE #{klass.quoted_table_name}") if wants_truncate?
        table.each_row do |row|
          if errata
            next if errata.rejects?(row)
            errata.correct!(row)
          end
          if uses_existing_data?
            key_values = key_attributes.map { |key_attr| [ key_attr.value_from_row(self, row) ] }
            record_set = WilliamJamesCartesianProduct.cart_prod(*key_values).map do |combination|
              next if combination.include?(nil) and !wants_nil_keys?
              klass.send(dynamic_finder_name, *combination)
            end.flatten
          else
            record_set = klass.new
          end
          Array.wrap(record_set).each do |record|
            affected_attributes.each { |attr| attr.set_record_from_row(self, record, row) }
            record.save
          end
        end
        DataMiner.logger.info "performed #{signature}"
      end
      
      def wants_truncate?
        options[:truncate] == true or (!(options[:truncate] == false) and !uses_existing_data?)
      end
      
      def wants_nil_keys?
        options[:allow_nil_keys] == true
      end
      
      def uses_existing_data?
        @uses_existing_data ||= attributes.has_keys_for?(self) or attributes.has_conditional_writes_for?(self)
      end
      
      def dynamic_finder_name
        "find_or_initialize_by_#{key_attributes.map(&:name).join('_and_')}".to_sym
      end
    end
  end
end
