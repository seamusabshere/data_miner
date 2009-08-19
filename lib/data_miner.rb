require 'logger'

$:.unshift(File.dirname(__FILE__))
require 'error_builder'
require 'reportable'
require 'active_record_ext'
require 'attribute'
require 'attribute_collection'
require 'configuration'
require 'dictionary'
require 'error'
require 'report'
require 'step'
require 'step/associate'
require 'step/await'
require 'step/callback'
require 'step/derive'
require 'step/import'
require 'warning'

ActiveRecord::Base.send :include, DataMiner::ActiveRecordExt

module DataMiner
  mattr_accessor :logger
  self.logger = Object.const_defined?('RAILS_DEFAULT_LOGGER') ? RAILS_DEFAULT_LOGGER : Logger.new(STDERR)
  
  class << self
    def signature(options = {})
      Configuration.signature(options)
    end
    
    def report_on(options = {})
      Configuration.report_on(options)
    end

    def errors(options = {})
      Configuration.errors(options)
    end
  
    def warnings(options = {})
      Configuration.warnings(options)
    end
  
    def classes
      Configuration.classes.map(&:to_s)
    end
  
    def mine_data!(options = {})
      Configuration.perform(options)
    end

    def order!(&blk)
      Configuration.order!(&blk)
    end
  end
end
