class DataMiner
  class Process
    attr_reader :config
    attr_reader :method_id
    attr_reader :block_description
    attr_reader :blk

    def initialize(config, method_id_or_block_description, &blk)
      @config = config
      if block_given?
        @block_description = method_id_or_block_description
        @blk = blk
      else
        @method_id = method_id_or_block_description
      end
    end
    
    def resource
      config.resource
    end
    
    def inspect
      str = %{<#Process(#{resource})}
      if block_description
        str << %{ called block "#{block_description}"}
      else
        str << %{ called method :#{method_id}}
      end
      str << ">"
      str
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
