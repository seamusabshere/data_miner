require 'rubygems'
require 'bundler/setup'

if Bundler.definition.specs['debugger'].first
  require 'debugger'
elsif Bundler.definition.specs['ruby-debug'].first
  require 'ruby-debug'
end

require 'minitest/spec'
require 'minitest/autorun'
require 'minitest/reporters'
MiniTest::Unit.runner = MiniTest::SuiteRunner.new
MiniTest::Unit.runner.reporters << MiniTest::Reporters::SpecReporter.new

require 'active_record'
require 'logger'
ActiveRecord::Base.logger = Logger.new $stderr
ActiveRecord::Base.logger.level = Logger::INFO
# ActiveRecord::Base.logger.level = Logger::DEBUG
ActiveRecord::Base.establish_connection(
  'adapter' => 'mysql2',
  'database' => 'data_miner_test',
  'username' => 'root',
  'password' => 'password'
)

ActiveRecord::Base.mass_assignment_sanitizer = :strict

require 'data_miner'

def init_database(unit_converter = :conversions)
  cmd = %{mysql -u root -ppassword -e "DROP DATABASE data_miner_test; CREATE DATABASE data_miner_test CHARSET utf8"}
  $stderr.puts "Running `#{cmd}`..."
  system cmd
  $stderr.puts "Done."

  DataMiner::Run.auto_upgrade!
  DataMiner::Run::ColumnStatistic.auto_upgrade!
  DataMiner::Run.clear_locks

  DataMiner.unit_converter = unit_converter
end

def init_models
  require 'support/breed'
  require 'support/pet'
  Pet.auto_upgrade!

  ActiveRecord::Base.descendants.each do |model|
    model.attr_accessible nil
  end
end
