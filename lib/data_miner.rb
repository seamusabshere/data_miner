require 'singleton'
require 'set'
require 'active_support'
require 'active_support/version'
if ::ActiveSupport::VERSION::MAJOR >= 3
  require 'active_support/core_ext'
end
require 'active_record'
if RUBY_VERSION >= '1.9'
  begin
    require 'unicode_utils/downcase'
  rescue LoadError
    Kernel.warn '[data_miner] You may wish to include unicode_utils in your Gemfile to improve accuracy of downcasing'
  end
end

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

    # @private
    def downcase(str)
      defined?(::UnicodeUtils) ? ::UnicodeUtils.downcase(str) : str.downcase
    end

    # @private
    def upcase(str)
      defined?(::UnicodeUtils) ? ::UnicodeUtils.upcase(str) : str.upcase
    end

    # @private
    def compress_whitespace(str)
      str.gsub(INNER_SPACE, ' ').strip
    end

    # @private
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

  class Finish < ::StandardError; end
  class Skip < ::StandardError; end

  MUTEX = ::Mutex.new
  INNER_SPACE = /[ ]+/

  include ::Singleton

  attr_writer :logger

  def run(model_names = DataMiner.model_names)
    Run.stack do
      model_names.each do |model_name|
        model_name.constantize.run_data_miner!
      end
    end
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
      @model_names ||= ::Set.new
    end
  end

end

::ActiveRecord::Base.extend ::DataMiner::ActiveRecordExtensions
