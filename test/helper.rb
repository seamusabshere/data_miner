require 'rubygems'
require 'bundler'
Bundler.setup
require 'test/unit'
require 'shoulda'
require 'ruby-debug'
$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
require 'data_miner'
class Test::Unit::TestCase
end

test_log = File.open('test.log', 'w')
test_log.sync = true
DataMiner.logger = Logger.new test_log

# because some of the test files reference it
require 'errata'

ENV['WIP'] = 'true' if ENV['ALL'] == 'true'

$:.push File.dirname(__FILE__)
require 'support/test_database'

ActiveSupport::Inflector.inflections do |inflect|
  inflect.uncountable %w{ aircraft aircraft_deux census_division_deux census_division_trois }
end

