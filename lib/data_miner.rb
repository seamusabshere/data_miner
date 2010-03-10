require 'active_support'
require 'active_record'
require 'blockenspiel'
require 'conversions'
require 'remote_table'
require 'errata'
require 'andand'
require 'log4r'

require 'data_miner/attribute'
require 'data_miner/configuration'
require 'data_miner/dictionary'
require 'data_miner/import'
require 'data_miner/process'
require 'data_miner/run'

# TODO: move to gem
require 'data_miner/william_james_cartesian_product'

module DataMiner
  class MissingHashColumn < RuntimeError; end
  
  include Log4r

  mattr_accessor :logger
  
  def self.start_logging
    if defined?(Rails)
      self.logger = Rails.logger
    else
      self.logger = Logger.new 'data_miner'
      logger.outputters = FileOutputter.new 'f1', :filename => 'data_miner.log'
    end
  end
  
  def self.run(options = {})
    DataMiner::Configuration.run options
  end
  
  def self.resource_names
    DataMiner::Configuration.resource_names
  end
  
  def self.create_tables
    DataMiner::Configuration.create_tables
  end
end

ActiveRecord::Base.class_eval do
  def self.data_miner(&block)
    unless table_exists?
      logger.error "[DataMiner gem] Database table `#{table_name}` doesn't exist. DataMiner probably won't work properly until you run a migration or otherwise fix the schema."
      return
    end
    
    DataMiner.resource_names.add self.name
    DataMiner.create_tables

    belongs_to :data_miner_last_run, :class_name => 'DataMiner::Run'
    
    # this is class_eval'ed here so that each ActiveRecord descendant has its own copy, or none at all
    class_eval do
      cattr_accessor :data_miner_config
      def self.data_miner_runs
        DataMiner::Run.scoped :conditions => { :resource_name => name }
      end
      def self.run_data_miner!(options = {})
        data_miner_config.run options
      end
    end
    self.data_miner_config = DataMiner::Configuration.new self

    Blockenspiel.invoke block, data_miner_config
    data_miner_config.after_invoke
  end
end

DataMiner.start_logging

# todo: move to conversions gem (maybe)
Conversions.register :miles, :nautical_miles, 0.868976242
Conversions.register :kilometres, :nautical_miles, 0.539956803
Conversions.register :pounds_per_gallon, :kilograms_per_litre, 0.119826427
Conversions.register :inches, :meters, 0.0254
Conversions.register :kilowatt_hours, :watt_hours, 1_000.0
Conversions.register :watt_hours, :joules, 3_600.0
Conversions.register :kilowatt_hours, :joules, 3_600_000.0
Conversions.register :kbtus, :btus, 1_000.0
Conversions.register :square_feet, :square_metres, 0.09290304
Conversions.register :pounds_per_square_foot, :kilograms_per_square_metre, 4.88242764
Conversions.register :kilograms_per_kilowatt_hour, :kilograms_per_megawatt_hour, 1_000.0
Conversions.register :btus, :joules, 1_055.05585
Conversions.register :kbtus, :joules, 1_000.0 * 1_055.05585
Conversions.register :cords, :joules, 2.11011171e10
Conversions.register :gallons_per_mile, :litres_per_kilometre, 2.35214583
Conversions.register :pounds_per_mile, :kilograms_per_kilometre, 0.281849232
Conversions.register :dollars, :cents, 100
Conversions.register :cubic_feet, :cubic_metres, 0.0283168466
Conversions.register :kilocalories_per_pound, :joules_per_kilogram, 9_224.14105
Conversions.register :grams_per_kilocalorie, :kilograms_per_joule, 2.39005736e-7
Conversions.register :joules, :kilocalories, 0.000239005736
