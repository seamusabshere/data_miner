module DataMiner
  class Step
    class Derive < Step
      def signature
        "#{super} #{affected_attributes.first.name}"
      end
    end
  end
end
