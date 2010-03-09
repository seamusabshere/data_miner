module DataMiner
  class Run < ActiveRecord::Base
    set_table_name 'data_miner_runs'
    default_scope :order => 'id ASC'
  end
end
