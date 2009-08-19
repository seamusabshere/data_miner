module DataMiner
  module ActiveRecordExt
    def self.included(klass)
      klass.extend(ClassMethods)
    end

    module ClassMethods
      def mine_data(options = {})
        class_eval { cattr_accessor :data_mine }
        self.data_mine = Configuration.new(self)
        yield data_mine
      end
      
      def data_mine_report_for_attribute(attr_name)
        self.data_mine.report_on(:affected => attr_name)
      end
    end
  end
end
