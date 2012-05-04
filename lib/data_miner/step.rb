class DataMiner
  class Step
    # @private
    def ==(other)
      other.class == self.class and other.description == description
    end

    # @private
    def model
      script.model
    end
  end
end
