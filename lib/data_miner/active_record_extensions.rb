require 'active_record'
require 'blockenspiel'

class DataMiner
  module ActiveRecordExtensions
    def data_miner(options = {}, &blk)
      ::DataMiner.instance.start_logging

      ::DataMiner.instance.resource_names.push self.name unless ::DataMiner.instance.resource_names.include? self.name

      # this is class_eval'ed here so that each ActiveRecord descendant has its own copy, or none at all
      class_eval do
        cattr_accessor :data_miner_config
        def self.data_miner_runs
          ::DataMiner::Run.scoped :conditions => { :resource_name => name }
        end
        def self.run_data_miner!(options = {})
          data_miner_config.run options
        end
      end

      if options[:append]
        self.data_miner_config ||= ::DataMiner::Config.new self
      else
        self.data_miner_config = ::DataMiner::Config.new self
      end

      ::Blockenspiel.invoke blk, data_miner_config

      data_miner_config.after_invoke
    end
  end
end


