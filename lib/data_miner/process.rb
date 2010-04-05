module DataMiner
  class Process
    attr_accessor :configuration, :position_in_run
    attr_accessor :method_name
    attr_accessor :block_description, :block
    delegate :resource, :to => :configuration

    def initialize(configuration, position_in_run, method_name_or_block_description, &block)
      @configuration = configuration
      @position_in_run = position_in_run
      if block_given?
        @block_description = method_name_or_block_description
        @block = block
      else
        @method_name = method_name_or_block_description
      end
    end
    
    def inspect
      str = "Process(#{resource}) position #{position_in_run}"
      if block
        str << " ran block (#{block_description})"
      else
        str << " called :#{method_name}"
      end
    end
    
    def run(run)
      if block
        block.call
      else
        resource.send method_name
      end
      DataMiner.log_info "ran #{inspect}"
    end
  end
end
