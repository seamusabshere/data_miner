require 'rubygems'
require 'bundler/setup'

if Bundler.definition.specs['ruby-debug19'].first or Bundler.definition.specs['ruby-debug'].first
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

def init_database
  cmd = %{mysql -u root -ppassword -e "DROP DATABASE data_miner_test; CREATE DATABASE data_miner_test CHARSET utf8"}
  $stderr.puts "Running `#{cmd}`..."
  system cmd
  $stderr.puts "Done."

  require 'data_miner'
  DataMiner::Run.auto_upgrade!
  DataMiner::Run::ColumnStatistic.auto_upgrade!
  DataMiner::Run.clear_locks

  require_relative './support/pet'
  require_relative './support/breed'

  ActiveRecord::Base.descendants.each do |model|
    model.attr_accessible nil
  end

  Pet.auto_upgrade!
end
