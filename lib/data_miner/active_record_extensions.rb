require 'active_record'
require 'blockenspiel'

class DataMiner
  module ActiveRecordExtensions
    def data_miner(options = {}, &blk)
      ::DataMiner.instance.start_logging

      ::DataMiner.logger.debug "Database table `#{table_name}` doesn't exist. It might be created in the data_miner block, but if it's not, DataMiner probably won't work properly until you run a migration or otherwise fix the schema." unless table_exists?

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
        def self.execute_schema
          if schema = data_miner_config.steps.detect { |s| s.instance_of?(::DataMiner::Schema) }
            schema.run
          end
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


