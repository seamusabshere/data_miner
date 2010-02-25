module DataMiner
  class Target < ActiveRecord::Base
    set_table_name 'data_miner_targets'
    set_primary_key :name
    has_many :runs, :class_name => '::DataMiner::Run', :foreign_key => 'data_miner_target_id'
  end
end
