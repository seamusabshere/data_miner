module DataMiner
  class Step
    class Associate < Step
      def signature
        "#{super} #{affected_attributes.first.name}"
      end
    end
  end
end
