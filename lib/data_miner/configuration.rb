module DataMiner
  class Configuration
    include Blockenspiel::DSL
    
    attr_accessor :resource, :runnables, :runnable_counter, :attributes

    def initialize(resource)
      @runnables = Array.new
      @resource = resource
      @runnable_counter = 0
      @attributes = HashWithIndifferentAccess.new
    end
    
    def process(method_name_or_block_description, &block)
      self.runnable_counter += 1
      runnables << DataMiner::Process.new(self, runnable_counter, method_name_or_block_description, &block)
    end

    def import(*args, &block)
      if args.length == 1
        description = '(no description)'
      else
        description = args.first
      end
      options = args.last
        
      self.runnable_counter += 1
      runnable = DataMiner::Import.new self, runnable_counter, description, options
      Blockenspiel.invoke block, runnable
      runnables << runnable
    end

    # Mine data for this class.
    def run(options = {})
      options.symbolize_keys!
      
      finished = false
      run = DataMiner::Run.create! :started_at => Time.now, :resource_name => resource.name
      resource.delete_all if options[:from_scratch]
      begin
        runnables.each { |runnable| runnable.run(run) }
        finished = true
      ensure
        run.update_attributes! :ended_at => Time.now, :finished => finished
      end
      nil
    end
    
    def import_runnables
      runnables.select { |runnable| runnable.is_a? Import }
    end
    
    def before_invoke
      
    end
    
    def after_invoke
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
      import_runnables.each do |runnable|
        runnable.attributes.each do |_, attribute|
          if attribute.options.any? { |k, _| k.to_s =~ /unit/ } and COMPLETE_UNIT_DEFINITIONS.none? { |complete_definition| complete_definition.all? { |required_option| attribute.options[required_option].present? } }
            DataMiner.logger.error %{

================================

[data_miner gem] You don't have a valid unit definition for #{resource.name}##{attribute.name}.

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
      import_runnables.each do |runnable|
        runnable.attributes.each do |_, attribute|
          DataMiner.logger.error "[data_miner gem] You can't have an attribute column that ends in _units (reserved): #{resource.table_name}.#{attribute.name}" if attribute.name.ends_with? '_units'
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
        DataMiner.logger.error %{

================================

[data_miner gem] On #{resource}, it looks like you're missing some columns...

Please run this...

  ./script/generate migration AddMissingColumnsTo#{resource.name}

and **replace** the resulting file with this:

  class AddMissingColumnsTo#{resource.name} < ActiveRecord::Migration
    def self.up
#{missing_columns.map { |column_name| "      add_column :#{resource.table_name}, :#{column_name}, :#{column_name.ends_with?('_units') ? 'string' : 'FIXME_WHAT_COLUMN_TYPE_AM_I' }" }.join("\n") }
    end
    
    def self.down
#{missing_columns.map { |column_name| "      remove_column :#{resource.table_name}, :#{column_name}" }.join("\n") }
    end
  end

On the other hand, if you're working directly with create_table, this might be helpful:

#{missing_columns.map { |column_name| "t.#{column_name.ends_with?('_units') ? 'string' : 'FIXME_WHAT_COLUMN_TYPE_AM_I' } '#{column_name}'" }.join("\n") }

================================
        }
      end
    end
    
    cattr_accessor :resource_names
    self.resource_names = Array.new
    class << self
      # Mine data. Defaults to all resource_names touched by DataMiner.
      #
      # Options
      # * <tt>:resource_names</tt>: array of resource (class) names to mine
      def run(options = {})
        options.symbolize_keys!
        
        resource_names.each do |resource_name|
          if options[:resource_names].blank? or options[:resource_names].include?(resource_name)
            resource_name.constantize.data_miner_config.run options
          end
        end
      end
            
      def create_tables
        c = ActiveRecord::Base.connection
        unless c.table_exists?('data_miner_runs')
          c.create_table 'data_miner_runs', :options => 'ENGINE=InnoDB default charset=utf8' do |t|
            t.string 'resource_name'
            t.boolean 'finished'
            t.datetime 'started_at'
            t.datetime 'ended_at'
            t.datetime 'created_at'
            t.datetime 'updated_at'
          end
        end
      end
    end
  end
end
