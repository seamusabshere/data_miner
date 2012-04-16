require 'benchmark'

class DataMiner
  class Config
    COMPLETE_UNIT_DEFINITIONS = [
      %w{units},
      %w{from_units to_units},
      %w{units_field_name},
      %w{units_field_name to_units},
      %w{units_field_number},
      %w{units_field_number to_units}
    ]

    attr_reader :model
    attr_reader :steps

    def initialize(model)
      @model = model
      @steps = []
    end

    def append_block(blk)
      instance_eval(&blk)
      if model.table_exists?
        make_sure_unit_definitions_make_sense
      end
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

    def make_sure_unit_definitions_make_sense
      steps.select do |step|
        step.is_a? Import
      end.each do |import_step|
        import_step.attributes.each do |_, attribute|
          if attribute.options.any? { |k, _| k.to_s =~ /unit/ } and COMPLETE_UNIT_DEFINITIONS.none? { |complete_definition| complete_definition.all? { |required_option| attribute.options[required_option].present? } }
            raise %{

================================

You don't have a valid unit definition for #{model.name}##{attribute.name}.

You supplied #{attribute.options.keys.select { |k, _| k.to_s =~ /unit/ }.inspect }.

You need to supply one of #{COMPLETE_UNIT_DEFINITIONS.map(&:inspect).to_sentence}".

================================
            }
          end
        end
      end
    end
  end
end
