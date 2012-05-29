require 'alchemist'

class DataMiner
  class UnitConverter
    class Alchemist < UnitConverter
      def convert(value, from, to)
        super
        value.to_f.send(from).to.send(to)
      end
    end
  end
end
