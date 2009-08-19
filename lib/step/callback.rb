module DataMiner
  class Step
    class Callback < Step
      attr_accessor :foreign_step
      
      def initialize(configuration, foreign_step)
        @configuration = configuration
        @foreign_step = foreign_step
        @number = "(last)"
      end
      
      def perform
        foreign_step.callback
        DataMiner.logger.info "performed #{signature}"
      end
      
      def signature
        "#{super} (on behalf of #{foreign_step.signature})"
      end
    end
  end
end
