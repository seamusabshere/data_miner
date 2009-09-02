module DataMiner
  module ActiveRecordExt
    def self.included(klass)
      klass.extend(ClassMethods)
    end

    module ClassMethods
      def mine_data(options = {}, &block)
        if defined?(NO_DATA_MINER) and NO_DATA_MINER == true
          class_eval do
            class << self
              def data_mine
                raise "NO_DATA_MINER is set to true, so data_mine is not available"
              end
            end
          end
        else
          class_eval { cattr_accessor :data_mine }
          self.data_mine = Configuration.new(self)
          yield data_mine
        end
      end
    end
  end
end
