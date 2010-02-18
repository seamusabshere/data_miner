module DataMiner
  class Configuration
    include Blockenspiel::DSL
    
    attr_accessor :klass, :runnables, :runnable_counter, :attributes, :unique_indices

    def initialize(klass)
      @runnables = Array.new
      @unique_indices = Set.new
      @klass = klass
      @runnable_counter = 0
      @attributes = HashWithIndifferentAccess.new
    end

    def unique_index(*args)
      args.each { |arg| unique_indices.add arg }
    end
    
    def process(callback)
      self.runnable_counter += 1
      runnables << DataMiner::Process.new(self, runnable_counter, callback)
    end

    def import(options = {}, &block)
      self.runnable_counter += 1
      runnables << DataMiner::Import.new(self, runnable_counter, options, &block)
    end
    
    def before_invoke
      self.class.create_tables
    end
    
    def after_invoke
      if unique_indices.empty?
        raise(MissingHashColumn, "No unique_index defined for #{klass.name}, so you need a row_hash:string column.") unless klass.column_names.include?('row_hash')
        unique_indices.add 'row_hash'
      end
      runnables.select { |runnable| runnable.is_a?(Import) }.each { |runnable| unique_indices.each { |unique_index| runnable.store(unique_index) unless runnable.stores?(unique_index) } }
    end

    # Mine data for this class.
    def run
      target = DataMiner::Target.find_or_create_by_name klass.name
      run = target.runs.create! :started_at => Time.now
      begin
        runnables.each(&:run)
      ensure
        run.update_attributes! :ended_at => Time.now
      end
      nil
    end
    
    cattr_accessor :classes
    self.classes = []
    class << self
      # Mine data. Defaults to all classes touched by DataMiner.
      #
      # Options
      # * <tt>:class_names</tt>: provide an array class names to mine
      def run(options = {})
        classes.each do |klass|
          if options[:class_names].blank? or options[:class_names].include?(klass.name)
            klass.data_miner_config.run
          end
        end
      end
      
      # Queue up all the ActiveRecord classes that DataMiner should touch.
      #
      # Generally done in <tt>config/initializers/data_miner_config.rb</tt>.
      def enqueue(&block)
        yield self.classes
      end
      
      def create_tables
        c = ActiveRecord::Base.connection
        unless c.table_exists?('data_miner_targets')
          c.create_table 'data_miner_targets', :options => 'ENGINE=InnoDB default charset=utf8', :id => false do |t|
            t.string 'name'
            t.datetime 'created_at'
            t.datetime 'updated_at'
          end
          c.execute 'ALTER TABLE data_miner_targets ADD PRIMARY KEY (name);'
        end
        unless c.table_exists?('data_miner_runs')
          c.create_table 'data_miner_runs', :options => 'ENGINE=InnoDB default charset=utf8' do |t|
            t.string 'data_miner_target_id'
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
