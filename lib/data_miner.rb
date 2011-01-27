require 'active_support'
require 'active_support/version'
%w{
  active_support/core_ext/array/conversions
  active_support/core_ext/string/access
  active_support/core_ext/string/multibyte
}.each do |active_support_3_requirement|
  require active_support_3_requirement
end if ::ActiveSupport::VERSION::MAJOR == 3

require 'singleton'

class DataMiner
  include ::Singleton
  
  class MissingHashColumn < StandardError; end
  class Finish < StandardError; end
  class Skip < StandardError; end
  class VerificationFailed < StandardError; end
  
  autoload :ActiveRecordExtensions, 'data_miner/active_record_extensions'
  autoload :Attribute, 'data_miner/attribute'
  autoload :Config, 'data_miner/config'
  autoload :Dictionary, 'data_miner/dictionary'
  autoload :Import, 'data_miner/import'
  autoload :Tap, 'data_miner/tap'
  autoload :Process, 'data_miner/process'
  autoload :Run, 'data_miner/run'
  autoload :Schema, 'data_miner/schema'
  autoload :Verify, 'data_miner/verify'
  
  class << self
    delegate :logger, :to => :instance
    delegate :logger=, :to => :instance
    delegate :run, :to => :instance
    delegate :resource_names, :to => :instance
  end
  
  # TODO this should probably live somewhere else
  def self.backtick_with_reporting(cmd)
    cmd = cmd.gsub /[ ]*\n[ ]*/m, ' '
    output = `#{cmd}`
    if not $?.success?
      raise %{
From the data_miner gem...

Command failed:
#{cmd}

Output:
#{output}
}
    end
  end
  
  attr_accessor :logger

  def resource_names
    @resource_names ||= []
  end

  def call_stack
    @call_stack ||= []
  end
  
  def start_logging
    if logger.nil?
      if defined? Rails
        self.logger = Rails.logger
      else
        require 'logger'
        self.logger = Logger.new $stdout
      end
    end
    ActiveRecord::Base.logger = logger
  end
    
  # Mine data. Defaults to all resource_names touched by DataMiner.
  #
  # Options
  # * <tt>:resource_names</tt>: array of resource (class) names to mine
  def run(options = {})
    options = options.dup
    options.stringify_keys!
    options['preserve_call_stack_between_runs'] = true
    resource_names.each do |resource_name|
      if options['resource_names'].blank? or options['resource_names'].include?(resource_name)
        resource_name.constantize.data_miner_config.run options
      end
    end
    call_stack.clear
    # RemoteTable.cleanup
  end
end

require 'active_record'
::ActiveRecord::Base.extend ::DataMiner::ActiveRecordExtensions
