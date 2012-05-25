require 'conversions'

class DataMiner
  class UnitConverter
    class Conversions < UnitConverter
      def convert(value, from, to)
        super
        value.to_f.send(from).to(to)
      end
    end
  end
end
