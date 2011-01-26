class DataMiner
  class Run < ::ActiveRecord::Base
    set_table_name 'data_miner_runs'
    
    def resource
      resource_name.constantize
    end
        
    class << self
      def create_tables
        return if table_exists?
        connection.create_table 'data_miner_runs', :force => true do |t|
          t.string 'resource_name'
          t.boolean 'killed'
          t.boolean 'skipped'
          t.boolean 'finished'
          t.datetime 'started_at'
          t.datetime 'terminated_at'
          t.datetime 'created_at'
          t.datetime 'updated_at'
        end
        reset_column_information
      end
    end
  end
end
