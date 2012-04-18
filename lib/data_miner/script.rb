class DataMiner
  class Script
    class << self
      # @private
      # activerecord-3.2.3/lib/active_record/scoping.rb
      def uniq
        previous_uniq = current_uniq
        Script.current_uniq = true
        begin
          yield
        ensure
          Script.current_uniq = previous_uniq
        end
      end

      def current_stack
        ::Thread.current[STACK_THREAD_VAR] ||= []
      end

      def current_stack=(stack)
        ::Thread.current[STACK_THREAD_VAR] = stack
      end

      def current_uniq
        ::Thread.current[UNIQ_THREAD_VAR]
      end

      def current_uniq=(uniq)
        ::Thread.current[UNIQ_THREAD_VAR] = uniq
      end
    end

    UNIQ_THREAD_VAR = 'DataMiner::Script.current_uniq'
    STACK_THREAD_VAR = 'DataMiner::Script.current_stack'

    attr_reader :model
    attr_reader :steps

    def initialize(model)
      @model = model
      @steps = []
    end

    def append_block(blk)
      instance_eval(&blk)
    end

    def process(method_id_or_description, &blk)
      append(:process, method_id_or_description, &blk)
    end

    def tap(description, source, options = {})
      append :tap, description, source, options
    end

    def import(description = nil, options = {}, &blk)
      append(:import, description, options, &blk)
    end

    def prepend_once(*args, &blk)
      step = make(*args, &blk)
      unless steps.include? step
        steps.unshift step
      end
    end

    def prepend(*args, &blk)
      steps.unshift make(*args, &blk)
    end

    def append_once(*args, &blk)
      step = make(*args, &blk)
      unless steps.include? step
        steps << step
      end
    end

    def append(*args, &blk)
      steps << make(*args, &blk)
    end

    def perform
      model_name = model.name
      # $stderr.write "0 - #{model_name}\n"
      # $stderr.write "A - current_uniq - #{Script.current_uniq ? 'true' : 'false'}\n"
      # $stderr.write "B - #{Script.current_stack.join(',')}\n"
      if Script.current_uniq and Script.current_stack.include?(model_name)
        # we've already done this in the current stack, so skip it
        return
      end
      if not Script.current_uniq
        # since we're not trying to uniq, ignore the current contents of the stack
        Script.current_stack.clear
      end
      Script.current_stack << model_name
      Run.new(:model_name => model_name).perform do
        steps.each do |step|
          step.perform
          model.reset_column_information
        end
      end
    end
        
    private

    def make(*args, &blk)
      klass = Step.const_get(args.shift.to_s.camelcase)
      options = args.extract_options!
      if args.empty?
        args = ["#{klass.name.demodulize} step with no description"]
      end
      initializer = [self] + args + [options]
      klass.new(*initializer, &blk)
    end
  end
end
