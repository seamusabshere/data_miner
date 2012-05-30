class DataMiner
  class UnitConverter
    class << self
      def load(type)
        if type
          require "data_miner/unit_converter/#{type}"
          const_get(type.to_s.camelcase).new
        end
      end
    end
  end
end
