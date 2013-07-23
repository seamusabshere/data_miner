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
    # oh well.
  end
end

require 'data_miner/active_record_class_methods'
require 'data_miner/attribute'
require 'data_miner/script'
require 'data_miner/dictionary'
require 'data_miner/step'
require 'data_miner/step/import'
require 'data_miner/step/process'
require 'data_miner/step/sql'

# A singleton class that holds global configuration for data mining.
#
# All of its instance methods are delegated to +DataMiner.instance+, so you can call +DataMiner.model_names+, for example.
#
# @see DataMiner::ActiveRecordClassMethods#data_miner Overview of how to define data miner scripts inside of ActiveRecord models.
class DataMiner
  class << self
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
      str.gsub(INNER_SPACE, ONE_SPACE).strip
    end
  end

  INNER_SPACE = /[ ]+/
  ONE_SPACE = ' '

  include ::Singleton

  attr_writer :logger

  # Run data miner scripts on models identified by their names. Defaults to all models.
  #
  # @param [optional, Array<String>] model_names Names of models to be run.
  #
  # @return nil
  def start(model_names = DataMiner.model_names)
    Script.uniq do
      model_names.map do |model_name|
        model_name.constantize.run_data_miner!
      end
    end
    nil
  end

  # legacy
  alias :run :start

  # Where DataMiner logs to. Defaults to +Rails.logger+ or +ActiveRecord::Base.logger+ if either is available.
  #
  # @return [Logger]
  def logger
    @logger || ::Thread.exclusive do
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

  # Names of the models that have defined a data miner script.
  #
  # @note Models won't appear here until the files containing their data miner scripts have been +require+'d.
  #
  # @return [Set<String>]
  def model_names
    @model_names || ::Thread.exclusive do
      @model_names ||= ::Set.new
    end
  end

  class << self
    delegate(*DataMiner.instance_methods(false), :to => :instance)
  end
end

DataMiner.model_names
::ActiveRecord::Base.extend ::DataMiner::ActiveRecordClassMethods
