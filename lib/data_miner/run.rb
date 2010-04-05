module DataMiner
  class Run < ActiveRecord::Base
    set_table_name 'data_miner_runs'
    
    def resource
      resource_name.constantize
    end
    
    def resource_records_last_touched_by_me
      resource.scoped :conditions => { :data_miner_last_run_id => id }
    end
  end
end
