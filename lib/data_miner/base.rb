module DataMiner
  class Base
    include Blockenspiel::DSL
    
    attr_accessor :resource, :steps, :step_counter, :attributes

    def initialize(resource)
      @steps = Array.new
      @resource = resource
      @step_counter = 0
      @attributes = HashWithIndifferentAccess.new
    end
    
    def schema(create_table_options = {}, &block)
      step = DataMiner::Schema.new self, step_counter, create_table_options
      Blockenspiel.invoke block, step
      steps << step
      self.step_counter += 1
    end
    
    def process(method_name_or_block_description, &block)
      steps << DataMiner::Process.new(self, step_counter, method_name_or_block_description, &block)
      self.step_counter += 1
    end

    def tap(description, source, options = {})
      steps << DataMiner::Tap.new(self, step_counter, description, source, options)
      self.step_counter += 1
    end

    def import(*args, &block)
      if args.length == 1
        description = '(no description)'
      else
        description = args.first
      end
      options = args.last
        
      step = DataMiner::Import.new self, step_counter, description, options
      Blockenspiel.invoke block, step
      steps << step
      self.step_counter += 1
    end

    # Mine data for this class.
    def run(options = {})
      options.symbolize_keys!
      
      return if DataMiner::Base.call_stack.include? resource.name
      DataMiner::Base.call_stack.push resource.name
      
      finished = false
      skipped = false
      if DataMiner::Run.table_exists?
        run = DataMiner::Run.create! :started_at => Time.now, :resource_name => resource.name, :killed => true
      else
        run = nil
        DataMiner.log_info "Not logging individual runs. Please run DataMiner::Run.create_tables if you want to enable this."
      end
      resource.delete_all if options[:from_scratch]
      begin
        steps.each do |step|
          step.run run
          resource.reset_column_information
        end
        finished = true
      rescue DataMiner::Finish
        finished = true
      rescue DataMiner::Skip
        skipped = true
      ensure
        if DataMiner::Run.table_exists?
          run.update_attributes! :terminated_at => Time.now, :finished => finished, :skipped => skipped, :killed => false
        end
        DataMiner::Base.call_stack.clear if DataMiner::Base.call_stack.first == resource.name and !options[:preserve_call_stack_between_runs]
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
      [:units],
      [:from_units, :to_units],
      [:units_field_name],
      [:units_field_name, :to_units],
      [:units_field_number],
      [:units_field_number, :to_units]
    ]
    
    def make_sure_unit_definitions_make_sense
      import_steps.each do |step|
        step.attributes.each do |_, attribute|
          if attribute.options.any? { |k, _| k.to_s =~ /unit/ } and COMPLETE_UNIT_DEFINITIONS.none? { |complete_definition| complete_definition.all? { |required_option| attribute.options[required_option].present? } }
            DataMiner.log_or_raise %{

================================

You don't have a valid unit definition for #{resource.name}##{attribute.name}.

You supplied #{attribute.options.keys.select { |k, _| k.to_s =~ /unit/ }.map(&:to_sym).inspect }.

You need to supply one of #{COMPLETE_UNIT_DEFINITIONS.map(&:inspect).to_sentence}".

================================
            }
          end
        end
      end
    end
    
    def suggest_missing_column_migrations
      missing_columns = Array.new
      
      import_steps.each do |step|
        step.attributes.each do |_, attribute|
          DataMiner.log_or_raise "You can't have an attribute column that ends in _units (reserved): #{resource.table_name}.#{attribute.name}" if attribute.name.end_with? '_units'
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
        DataMiner.log_debug %{

================================

On #{resource}, it looks like you're missing some columns...

Please run this...

  ./script/generate migration AddMissingColumnsTo#{resource.name}

and **replace** the resulting file with this:

  class AddMissingColumnsTo#{resource.name} < ActiveRecord::Migration
    def self.up
#{missing_columns.map { |column_name| "      add_column :#{resource.table_name}, :#{column_name}, :#{column_name.end_with?('_units') ? 'string' : 'FIXME_WHAT_COLUMN_TYPE_AM_I' }" }.join("\n") }
    end
    
    def self.down
#{missing_columns.map { |column_name| "      remove_column :#{resource.table_name}, :#{column_name}" }.join("\n") }
    end
  end

On the other hand, if you're working directly with create_table, this might be helpful:

#{missing_columns.map { |column_name| "t.#{column_name.end_with?('_units') ? 'string' : 'FIXME_WHAT_COLUMN_TYPE_AM_I' } '#{column_name}'" }.join("\n") }

================================
        }
      end
    end
    
    cattr_accessor :resource_names
    self.resource_names = Array.new
    
    cattr_accessor :call_stack
    self.call_stack = Array.new
    class << self
      # Mine data. Defaults to all resource_names touched by DataMiner.
      #
      # Options
      # * <tt>:resource_names</tt>: array of resource (class) names to mine
      def run(options = {})
        options.symbolize_keys!
        
        resource_names.each do |resource_name|
          if options[:resource_names].blank? or options[:resource_names].include?(resource_name)
            resource_name.constantize.data_miner_base.run options
          end
        end
      ensure
        RemoteTable.cleanup
      end
    end
  end
end
