module DataMiner
  module ErrorBuilder
    def build_errors
      errors = []
      yield errors
      errors
    end
  end
end
