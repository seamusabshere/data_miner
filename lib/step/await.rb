module DataMiner
  class Step
    class Await < Step
      attr_accessor :other_class
      
      def initialize(configuration, number, options = {}, &block)
        @configuration = configuration
        @number = number
        @options = options
        @other_class = options.delete(:other_class)
        configuration.awaiting!(self)
        yield configuration # pull in steps
        configuration.stop_awaiting!
      end
      
      def perform
        other_class.data_mine.steps << Step::Callback.new(other_class.data_mine, self)
        DataMiner.logger.info "added #{signature} to callbacks after #{other_class}"
      end
      
      def callback
        DataMiner.logger.info "starting to perform deferred steps in #{signature}..."
        all_awaiting.each { |step| step.perform(true) }
        DataMiner.logger.info "...done"
      end
      
      private
      
      def all_awaiting
        configuration.steps.find_all { |step| step.options and step.options[:awaiting] == self }
      end
    end
  end
end
