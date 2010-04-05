module DataMiner
  class Run < ActiveRecord::Base
    set_table_name 'data_miner_runs'
    
    def resource
      resource_name.constantize
    end
    
    def resource_records_last_touched_by_me
      resource.scoped :conditions => { :data_miner_last_run_id => id }
    end
    
    class << self
      def create_tables
        return if table_exists?
        connection.create_table 'data_miner_runs' do |t|
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
