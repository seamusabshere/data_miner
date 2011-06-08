require 'active_record'
require 'blockenspiel'

class DataMiner
  module ActiveRecordExtensions
    def data_miner_config
      @data_miner_config ||= ::DataMiner::Config.new self
    end
    
    def data_miner_config=(config)
      @data_miner_config = config
    end
    
    def data_miner_runs
      ::DataMiner::Run.scoped :conditions => { :resource_name => name }
    end

    def run_data_miner!(options = {})
      data_miner_config.run options
    end
    
    def run_data_miner_on_parent_associations!
      reflect_on_all_associations(:belongs_to).each do |assoc|
        next if assoc.options[:polymorphic]
        assoc.klass.run_data_miner!
      end
    end
    
    def data_miner(options = {}, &blk)
      ::DataMiner.instance.start_logging

      ::DataMiner.instance.resource_names.push self.name unless ::DataMiner.instance.resource_names.include? self.name

      unless options[:append]
        self.data_miner_config = ::DataMiner::Config.new self
      end

      ::Blockenspiel.invoke blk, data_miner_config

      data_miner_config.after_invoke
    end
  end
end


