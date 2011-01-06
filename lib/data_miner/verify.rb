module DataMiner
  class Verify
    attr_accessor :base, :position_in_run, :check, :description
    delegate :resource, :to => :base
    
    def initialize(base, position_in_run, description, check)
      self.base = base
      self.position_in_run = position_in_run
      self.description = description
      self.check = check
    end

    def inspect
      "Verify(#{resource}) position #{position_in_run} (#{description})"
    end

    def run(run)
      unless check.call
        raise VerificationFailed, "FAILED VERIFICATION: #{inspect}"
      end
      DataMiner.log_info "performed #{inspect}"
    end
  end
end
