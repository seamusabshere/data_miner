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
      runnables << DataMiner::Import.new(self, runnable_counter, description, options, &block)
    end
        
    def after_invoke
      if unique_indices.empty?
        raise(MissingHashColumn, "No unique_index defined for #{klass.name}, so you need a row_hash:string column.") unless klass.column_names.include?('row_hash')
        unique_indices.add 'row_hash'
      end
      runnables.select { |runnable| runnable.is_a?(Import) }.each { |runnable| unique_indices.each { |unique_index| runnable.store(unique_index) unless runnable.stores?(unique_index) } }
    end

    # Mine data for this class.
    def run(options = {})
      target = DataMiner::Target.find(klass.name)
      finished = false
      run = target.runs.create! :started_at => Time.now
      klass.delete_all if options[:from_scratch]
      begin
        runnables.each { |runnable| runnable.run(run) }
        finished = true
      ensure
        run.update_attributes! :ended_at => Time.now, :finished => finished
      end
      nil
    end
    
    cattr_accessor :classes
    self.classes = Set.new
    class << self
      # Mine data. Defaults to all classes touched by DataMiner.
      #
      # Options
      # * <tt>:class_names</tt>: provide an array class names to mine
      def run(options = {})
        classes.each do |klass|
          if options[:class_names].blank? or options[:class_names].include?(klass.name)
            klass.data_miner_config.run options
          end
        end
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
