require 'singleton'
require 'active_support'
require 'active_support/version'
if ::ActiveSupport::VERSION::MAJOR >= 3
  require 'active_support/core_ext'
end

require 'active_record'

require 'data_miner/active_record_extensions'
require 'data_miner/attribute'
require 'data_miner/config'
require 'data_miner/dictionary'
require 'data_miner/step'
require 'data_miner/step/import'
require 'data_miner/step/tap'
require 'data_miner/step/process'
require 'data_miner/run'

class DataMiner
  class << self
    delegate :run, :to => :instance
    delegate :logger, :to => :instance
    delegate :logger=, :to => :instance
    delegate :model_names, :to => :instance

    # http://devblog.avdi.org/2009/07/14/recursively-symbolize-keys/
    def recursively_symbolize_keys(hash)
      hash.inject(::Hash.new) do |result, (key, value)|
        new_key   = case key
                    when ::String then key.to_sym
                    else key
                    end
        new_value = case value
                    when ::Hash then DataMiner.recursively_symbolize_keys(value)
                    else value
                    end
        result[new_key] = new_value
        result
      end
    end
  end

  class Finish < StandardError; end
  class Skip < StandardError; end

  # thread safety
  MUTEX = ::Mutex.new

  include ::Singleton

  attr_writer :logger

  def run(model_names = DataMiner.model_names)
    finished = []
    model_names.each do |model_name|
      Run.new(:model_name => model_name).perform finished
    end
    finished
  end

  def logger
    @logger || MUTEX.synchronize do
      @logger ||= if defined?(::Rails)
        ::Rails.logger
      elsif defined?(::ActiveRecord) and active_record_logger = ::ActiveRecord::Base.logger
        active_record_logger
      else
        require 'logger'
        ::Logger.new $stderr
      end
    end
  end

  def model_names
    @model_names || MUTEX.synchronize do
      @model_names ||= []
    end
  end

end

::ActiveRecord::Base.extend ::DataMiner::ActiveRecordExtensions
