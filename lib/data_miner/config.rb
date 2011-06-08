require 'blockenspiel'
require 'benchmark'

class DataMiner
  class Config
    include ::Blockenspiel::DSL
    
    attr_reader :resource

    def initialize(resource)
      @resource = resource
    end
    
    def steps
      @steps ||= []
    end
    
    # def attributes
    #   @attributes ||= {}
    # end
        
    def process(method_id_or_block_description, &blk)
      step = Process.new self, method_id_or_block_description, &blk
      steps.push step
    end

    def tap(description, source, options = {})
      step = Tap.new self, description, source, options
      steps.push step
    end

    def import(*args, &blk)
      if args.length == 1
        description = '(no description)'
      else
        description = args[0]
      end
      options = args.last
        
      step = Import.new self, description, options
      ::Blockenspiel.invoke blk, step
      steps.push step
    end

    def verify(description = '(no description)', &blk)
      step = Verify.new self, description, &blk
      steps.push step
    end

    # Mine data for this class.
    def run(options = {})
      options = options.dup
      options.stringify_keys!
      
      return if ::DataMiner.instance.call_stack.include? resource.name
      ::DataMiner.instance.call_stack.push resource.name
      
      finished = false
      skipped = false
      if Run.table_exists?
        run = Run.create! :started_at => ::Time.now, :resource_name => resource.name, :killed => true
      else
        run = nil
        ::DataMiner.logger.info "Not logging individual runs. Please run DataMiner::Run.create_tables if you want to enable this."
      end
      resource.delete_all if options['from_scratch']
      begin
        steps.each do |step|
          time = ::Benchmark.realtime { step.run }
          resource.reset_column_information
          ::DataMiner.logger.info %{Ran #{step.inspect} in #{time.to_i}}
        end
        finished = true
      rescue Finish
        finished = true
      rescue Skip
        skipped = true
      ensure
        if Run.table_exists?
          run.update_attributes! :terminated_at => ::Time.now, :finished => finished, :skipped => skipped, :killed => false
        end
        if ::DataMiner.instance.call_stack.first == resource.name and !options['preserve_call_stack_between_runs']
          ::DataMiner.instance.call_stack.clear
        end
      end
      nil
    end
    
    def import_steps
      steps.select { |step| step.is_a? Import }
    end
    
    def before_invoke
      
    end
    
    def after_invoke
      return unless resource.table_exists?
      make_sure_unit_definitions_make_sense
      suggest_missing_column_migrations
    end
    
    COMPLETE_UNIT_DEFINITIONS = [
      %w{units},
      %w{from_units to_units},
      %w{units_field_name},
      %w{units_field_name to_units},
      %w{units_field_number},
      %w{units_field_number to_units}
    ]
    
    def make_sure_unit_definitions_make_sense
      import_steps.each do |step|
        step.attributes.each do |_, attribute|
          if attribute.options.any? { |k, _| k.to_s =~ /unit/ } and COMPLETE_UNIT_DEFINITIONS.none? { |complete_definition| complete_definition.all? { |required_option| attribute.options[required_option].present? } }
            raise %{

================================

You don't have a valid unit definition for #{resource.name}##{attribute.name}.

You supplied #{attribute.options.keys.select { |k, _| k.to_s =~ /unit/ }.inspect }.

You need to supply one of #{COMPLETE_UNIT_DEFINITIONS.map(&:inspect).to_sentence}".

================================
            }
          end
        end
      end
    end
    
    def suggest_missing_column_migrations
      missing_columns = []
      
      import_steps.each do |step|
        step.attributes.each do |_, attribute|
          raise "You can't have an attribute column that ends in _units (reserved): #{resource.table_name}.#{attribute.name}" if attribute.name.end_with? '_units'
          unless resource.column_names.include? attribute.name
            missing_columns << attribute.name
          end
          if attribute.wants_units? and !resource.column_names.include?(units_column = "#{attribute.name}_units")
            missing_columns << units_column
          end
        end
      end
      missing_columns.uniq!
      if missing_columns.any?
        ::DataMiner.logger.debug %{

================================

On #{resource}, it looks like you're missing some columns...

#{missing_columns.map { |column_name| "#{column_name.end_with?('_units') ? 'string' : 'FIXME_WHAT_COLUMN_TYPE_AM_I' } '#{column_name}'" }.join("\n") }

================================
        }
      end
    end
  end
end
