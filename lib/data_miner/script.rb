class DataMiner
  class Script
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
      Run.perform(model) do
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
