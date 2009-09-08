require 'rubygems'
require 'activesupport'
require 'activerecord'
require 'conversions'
require 'remote_table'
require 'errata'

require 'data_miner/active_record_ext'
require 'data_miner/attribute'
require 'data_miner/attribute_collection'
require 'data_miner/configuration'
require 'data_miner/dictionary'
require 'data_miner/step'
require 'data_miner/step/associate'
require 'data_miner/step/await'
require 'data_miner/step/callback'
require 'data_miner/step/derive'
require 'data_miner/step/import'
require 'data_miner/william_james_cartesian_product' # TODO: move to gem

module DataMiner
  class << self
    def mine(options = {})
      DataMiner::Configuration.mine options
    end
    
    def map_to_attrs(method, options = {})
      puts DataMiner::Configuration.map_to_attrs(method, options)
    end

    def enqueue(&block)
      DataMiner::Configuration.enqueue &block
    end
    
    def classes
      DataMiner::Configuration.classes
    end
  end
end

ActiveRecord::Base.class_eval do
  include DataMiner::ActiveRecordExt
end
