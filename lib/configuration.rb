module DataMiner
  class Configuration
    attr_accessor :steps, :klass, :counter, :attributes, :awaiting

    def initialize(klass)
      @steps = []
      @klass = klass
      @counter = 0
      @attributes = AttributeCollection.new(klass)
    end

    %w(import associate derive await).each do |variant|
      eval <<-EOS
        def #{variant}(*args, &block)
          self.counter += 1
          if block_given? # FORM C
            step_options = args[0] || {}
            set_awaiting!(step_options)
            self.steps << Step::#{variant.camelcase}.new(self, counter, step_options, &block)
          elsif args[0].is_a?(Hash) # FORM A
            step_options = args[0]
            set_awaiting!(step_options)
            self.steps << Step::#{variant.camelcase}.new(self, counter, step_options)
          else # FORM B
            attr_name = args[0]
            attr_options = args[1] || {}
            step_options = {}
            set_awaiting!(step_options)
            self.steps << Step::#{variant.camelcase}.new(self, counter, step_options) do |attr|
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

    %w(signature report_on errors warnings perform).each do |method|
      eval <<-EOS
        def #{method}(options = {})
          number_whitelist = extract_number_whitelist!(options)
          map_to_steps(number_whitelist) { |step| options.blank? ? step.#{method} : step.#{method}(options.dup) }.compact.flatten
        end
      EOS
    end
    
    private

    def map_to_steps(number_whitelist, &block)
      steps.map do |step|
        next unless number_whitelist == :all or number_whitelist.include?(step.number)
        yield step
      end
    end

    def extract_number_whitelist!(options)
      whitelist = Array.wrap(options.delete(:numbers)).compact.map(&:to_i)
      whitelist = :all if whitelist.blank?
      whitelist
    end

    cattr_accessor :classes
    self.classes = []
    class << self
      %w(signature report_on errors warnings perform).each do |method|
        eval <<-EOS
          def #{method}(options = {})
            class_whitelist = extract_class_whitelist!(options)
            DataMiner.logger.warn "Running specific numbers (\#{options[:numbers].join(', ')}) without a specific class... this is going to be weird." if !options[:numbers].blank? and class_whitelist == :all
            map_to_configurations(class_whitelist) { |configuration| options.blank? ? configuration.#{method} : configuration.#{method}(options.dup) }.compact.flatten
          end
        EOS
      end

      def order!(&block)
        yield self.classes
      end

      private

      def map_to_configurations(class_whitelist, &block)
        classes.map(&:data_mine).map do |configuration|
          next unless class_whitelist == :all or class_whitelist.include?(configuration.klass)
          yield configuration
        end
      end

      def extract_class_whitelist!(options)
        whitelist = Array.wrap(options.delete(:classes)).compact.map { |e| e.to_s.constantize }
        whitelist = :all if whitelist.blank?
        whitelist
      end
    end
  end
end
