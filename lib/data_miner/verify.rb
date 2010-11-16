module DataMiner
  class Verify
    class VerificationFailed < RuntimeError; end

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
      begin
        verification = check.call
      rescue Exception => e  # need this to catch Test::Unit assertions
        raise VerificationFailed,
          "#{e.inspect}: #{e.backtrace.join("\n")}"
      rescue => e
        raise VerificationFailed,
          "#{e.inspect}: #{e.backtrace.join("\n")}"
      end
      unless verification
        raise VerificationFailed, "Result of check was false" 
      end
      DataMiner.log_info "performed #{inspect}"
    end
  end
end
