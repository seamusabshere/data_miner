require 'rubygems'
require 'activesupport'
require 'activerecord'
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

module DataMiner
  class << self
    def mine(options = {})
      Configuration.mine options
    end

    def enqueue(&block)
      Configuration.enqueue &block
    end
  end
end

ActiveRecord::Base.class_eval do
  include DataMiner::ActiveRecordExt
end
