class DataMiner
  class Verify
    attr_accessor :config, :description, :blk
    
    def initialize(config, description, &blk)
      @config = config
      @description = description
      @blk = blk
    end
    
    def resource
      config.resource
    end

    def inspect
      %{#<DataMiner::Verify(#{resource})  (#{description})>}
    end

    def run
      successful = begin
        blk.call
      rescue => e
        false
      end
      unless successful
        raise VerificationFailed, "FAILED VERIFICATION: #{inspect}"
      end
      nil
    end
  end
end
