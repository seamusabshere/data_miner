class DataMiner
  class Step
    # @private
    attr_reader :script

    # @private
    def ==(other)
      other.class == self.class and other.description == description
    end

    # @private
    def model
      script.model
    end

    def pos
      script.steps.index self
    end

    def register(step)
      # noop
    end

    def notify(*args)
      # noop
    end

    def target?(*args)
      false
    end
  end
end
