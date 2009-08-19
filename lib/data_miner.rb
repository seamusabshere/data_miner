require 'rubygems'
require 'activesupport'
require 'activerecord'
require 'remote_table'
require 'errata'

# TODO: move to lib/data_miner
require 'active_record_ext'
require 'attribute'
require 'attribute_collection'
require 'configuration'
require 'dictionary'
require 'step'
require 'step/associate'
require 'step/await'
require 'step/callback'
require 'step/derive'
require 'step/import'

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
