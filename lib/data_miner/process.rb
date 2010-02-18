module DataMiner
  class Process
    attr_accessor :configuration, :position_in_run, :callback
    delegate :klass, :to => :configuration

    def initialize(configuration, position_in_run, callback)
      @configuration = configuration
      @position_in_run = position_in_run
      @callback = callback
    end
    
    def inspect
      "Process(#{klass}) position #{position_in_run}"
    end
    
    def run
      klass.send callback
      DataMiner.logger.info "ran #{inspect}"
    end
  end
end
