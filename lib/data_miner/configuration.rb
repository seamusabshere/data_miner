module DataMiner
  class Configuration
    attr_accessor :steps, :klass, :counter, :attributes, :awaiting

    def initialize(klass)
      @steps = []
      @klass = klass
      @counter = 0
      @attributes = AttributeCollection.new(klass)
    end

    %w(import associate derive await).each do |method|
      eval <<-EOS
        def #{method}(*args, &block)
          self.counter += 1
          if block_given? # FORM C
            step_options = args[0] || {}
            set_awaiting!(step_options)
            self.steps << Step::#{method.camelcase}.new(self, counter, step_options, &block)
          elsif args[0].is_a?(Hash) # FORM A
            step_options = args[0]
            set_awaiting!(step_options)
            self.steps << Step::#{method.camelcase}.new(self, counter, step_options)
          else # FORM B
            attr_name = args[0]
            attr_options = args[1] || {}
            step_options = {}
            set_awaiting!(step_options)
            self.steps << Step::#{method.camelcase}.new(self, counter, step_options) do |attr|
              attr.affect attr_name, attr_options
            end
          end
        end
      EOS
    end

    def set_awaiting!(step_options)
      step_options.merge!(:awaiting => awaiting) if !awaiting.nil?
    end

    def awaiting!(step)
      self.awaiting = step
    end
    
    def stop_awaiting!
      self.awaiting = nil
    end

    # Mine data for this class.
    def mine(options = {})
      steps.each { |step| step.perform options }
    end
    
    # Map <tt>method</tt> to attributes
    def map_to_attrs(method)
      steps.map { |step| step.map_to_attrs(method) }.compact
    end

    cattr_accessor :classes
    self.classes = []
    class << self
      # Mine data. Defaults to all classes touched by DataMiner.
      #
      # Options
      # * <tt>:class_names</tt>: provide an array class names to mine
      def mine(options = {})
        classes.each do |klass|
          if options[:class_names].blank? or options[:class_names].include?(klass.name)
            klass.data_mine.mine options
          end
        end
      end
      
      # Map a <tt>method</tt> to attrs. Defaults to all classes touched by DataMiner.
      #
      # Options
      # * <tt>:class_names</tt>: provide an array class names to mine
      def map_to_attrs(method, options = {})
        classes.map do |klass|
          if options[:class_names].blank? or options[:class_names].include?(klass.name)
            klass.data_mine.map_to_attrs method
          end
        end.flatten.compact
      end

      # Queue up all the ActiveRecord classes that DataMiner should touch.
      #
      # Generally done in <tt>config/initializers/data_miner_config.rb</tt>.
      def enqueue(&block)
        yield self.classes
      end
    end
  end
end
