class DataMiner
  class Process
    attr_reader :config
    attr_reader :method_id
    attr_reader :description
    attr_reader :blk

    alias :block_description :description

    def initialize(config, method_id_or_description, &blk)
      @config = config
      if block_given?
        @description = method_id_or_description
        @blk = blk
      else
        @description = method_id_or_description
        @method_id = method_id_or_description
      end
    end
    
    def resource
      config.resource
    end
    
    def inspect
      %{#<DataMiner::Process(#{resource}) #{description}>}
    end
    
    def run
      if blk
        blk.call
      else
        resource.send method_id
      end
      nil
    end
  end
end
