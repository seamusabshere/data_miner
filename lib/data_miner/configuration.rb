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
    
    cattr_accessor :resource_names
    self.resource_names = Set.new
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
