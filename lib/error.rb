module DataMiner
  class Error
    attr_accessor :instance, :message
    
    def initialize(instance, message)
      @instance = instance
      @message = message
    end
    
    def full_message
      <<-EOS
#{message}
  in #{instance.minor_label}
  in #{instance.major_label}

      EOS
    end
  end
end
