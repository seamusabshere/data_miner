module DataMiner
  class Target < ActiveRecord::Base
    set_table_name 'data_miner_targets'
    set_primary_key :name
    has_many :runs, :class_name => '::DataMiner::Run', :foreign_key => 'data_miner_target_id'

    def klass
      name.constantize
    end
    
    def run
      klass.data_miner_config.run
    end

    def included_in_list_of_targets
      msg = "must have a data_miner block"
      unless DataMiner.classes.include?(name.constantize)
        errors.add :name, msg
      end
    rescue NameError
      errors.add :name, msg
    end
    
    validate :included_in_list_of_targets
  end
end
