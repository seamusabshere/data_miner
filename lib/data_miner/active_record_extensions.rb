require 'active_record'

class DataMiner
  module ActiveRecordExtensions
    def data_miner_config
      @data_miner_config ||= DataMiner::Config.new self
    end
    
    def data_miner_runs
      DataMiner::Run.scoped :conditions => { :model_name => name }
    end

    def run_data_miner!
      data_miner_config.steps.each do |step|
        step.perform
        reset_column_information
      end
    end
    
    def run_data_miner_on_parent_associations!
      reflect_on_all_associations(:belongs_to).each do |assoc|
        next if assoc.options[:polymorphic]
        assoc.klass.run_data_miner!
      end
    end
    
    def data_miner(options = {}, &blk)
      unless DataMiner.instance.model_names.include?(name)
        DataMiner.instance.model_names << name
      end
      unless options[:append]
        @data_miner_config = DataMiner::Config.new self
      end
      data_miner_config.append_block blk
    end
  end
end
