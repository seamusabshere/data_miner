require 'active_record'
require 'lock_method'

class DataMiner
  module ActiveRecordExtensions
    MUTEX = ::Mutex.new

    def data_miner_script
      @data_miner_script || MUTEX.synchronize do
        @data_miner_script ||= DataMiner::Script.new(self)
      end
    end
    
    def data_miner_runs
      DataMiner::Run.scoped :conditions => { :model_name => name }
    end

    def run_data_miner!
      data_miner_script.perform
    end
    
    def run_data_miner_on_parent_associations!
      reflect_on_all_associations(:belongs_to).reject do |assoc|
        assoc.options[:polymorphic]
      end.each do |non_polymorphic_belongs_to_assoc|
        non_polymorphic_belongs_to_assoc.klass.run_data_miner!
      end
    end
    
    def data_miner(options = {}, &blk)
      DataMiner.model_names.add name
      unless options[:append]
        @data_miner_script = nil
      end
      data_miner_script.append_block blk
    end
  end
end
