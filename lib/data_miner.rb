require 'active_support'
require 'active_support/version'
%w{
  active_support/core_ext/array/conversions
  active_support/core_ext/string/access
  active_support/core_ext/string/multibyte
}.each do |active_support_3_requirement|
  require active_support_3_requirement
end if ActiveSupport::VERSION::MAJOR == 3

require 'active_record'
require 'blockenspiel'
require 'conversions'
require 'errata'
require 'remote_table'
require 'escape'
require 'andand'
require 'log4r'
require 'fileutils'
require 'tmpdir'
require 'zlib'

require 'data_miner/attribute'
require 'data_miner/base'
require 'data_miner/dictionary'
require 'data_miner/import'
require 'data_miner/tap'
require 'data_miner/process'
require 'data_miner/run'
require 'data_miner/schema'
require 'data_miner/verify'

module DataMiner
  class MissingHashColumn < StandardError; end
  class Finish < StandardError; end
  class Skip < StandardError; end
  
  mattr_accessor :logger
  
  def self.start_logging
    return if logger

    if defined? Rails
      self.logger = Rails.logger
    else
      class_eval { include Log4r }
      info_outputter = FileOutputter.new 'f1', :filename => 'data_miner.log'
      error_outputter = Outputter.stderr
      info_outputter.only_at DEBUG, INFO
      error_outputter.only_at WARN, ERROR, FATAL
      
      self.logger = Logger.new 'data_miner'
      logger.add info_outputter, error_outputter
      ActiveRecord::Base.logger = logger
    end
  end
  
  def self.log_or_raise(message)
    message = "[data_miner gem] #{message}"
    if ENV['RAILS_ENV'] == 'production' or ENV['DONT_RAISE'] == 'true'
      logger.error message
    else
      raise message
    end
  end
  
  def self.log_info(message)
    logger.info "[data_miner gem] #{message}"
  end
  
  def self.log_debug(message)
    logger.debug "[data_miner gem] #{message}"
  end
  
  def self.run(options = {})
    DataMiner::Base.run options.merge(:preserve_call_stack_between_runs => true)
    DataMiner::Base.call_stack.clear
  end
  
  def self.resource_names
    DataMiner::Base.resource_names
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

end

ActiveRecord::Base.class_eval do
  def self.x_data_miner(&block)
    DataMiner.start_logging
    
    DataMiner.log_debug "Skipping data_miner block in #{self.name} because called as x_data_miner"
  end
  
  def self.data_miner(&block)
    DataMiner.start_logging
    
    DataMiner.log_debug "Database table `#{table_name}` doesn't exist. It might be created in the data_miner block, but if it's not, DataMiner probably won't work properly until you run a migration or otherwise fix the schema." unless table_exists?
    
    DataMiner.resource_names.push self.name unless DataMiner.resource_names.include? self.name

    # this is class_eval'ed here so that each ActiveRecord descendant has its own copy, or none at all
    class_eval do
      cattr_accessor :data_miner_base
      def self.data_miner_runs
        DataMiner::Run.scoped :conditions => { :resource_name => name }
      end
      def self.run_data_miner!(options = {})
        data_miner_base.run options
      end
      def self.execute_schema
        schema = data_miner_base.steps.find { |s| s.instance_of?(DataMiner::Schema) }
        schema.run(nil) if schema
      end
    end
    self.data_miner_base = DataMiner::Base.new self

    Blockenspiel.invoke block, data_miner_base
    
    data_miner_base.after_invoke
  end
end
