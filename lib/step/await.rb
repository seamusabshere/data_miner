module DataMiner
  class Step
    class Await < Step
      attr_accessor :other_class
      
      def initialize(configuration, number, options = {}, &block)
        # doesn't call super
        @configuration = configuration
        @number = number
        @options = options
        @other_class = options.delete :other_class
        configuration.awaiting! self
        yield configuration # pull in steps
        configuration.stop_awaiting!
      end
      
      def perform
        other_class.data_mine.steps << Step::Callback.new(other_class.data_mine, self)
        $stderr.puts "added #{signature} to callbacks after #{other_class}"
      end
      
      def callback
        $stderr.puts "starting to perform deferred steps in #{signature}..."
        all_awaiting.each { |step| step.perform true }
        $stderr.puts "...done"
      end
      
      private
      
      def all_awaiting
        configuration.steps.select { |step| step.options and step.options[:awaiting] == self }
      end
    end
  end
end
