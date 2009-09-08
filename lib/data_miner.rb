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
    
    def dependencies(options = {})
      DataMiner::Configuration.dependencies(options).each do |d|
        unless d[:natural_order]
          str = "#{"#{d[:klass]}:".ljust(30)} #{d[:attr_name]} needs #{d[:reflection_klass]}."
          str << " it's not in natural order." 
          str << " it will create parents." if d[:create]
          puts str
        end
      end
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
