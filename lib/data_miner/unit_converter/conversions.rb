require 'conversions'

class DataMiner
  class UnitConverter
    class Conversions < UnitConverter
      def convert(value, from, to)
        value.to_f.convert from, to
      end
    end
  end
end
