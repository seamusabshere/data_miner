module DataMiner
  module ActiveRecordExt
    def self.included(klass)
      klass.extend(ClassMethods)
    end

    module ClassMethods
      def mine_data(options = {}, &block)
        class_eval { cattr_accessor :data_mine }
        self.data_mine = Configuration.new(self)
        yield data_mine
      end
    end
  end
end
