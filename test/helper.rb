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

cmd = %{mysql -u root -ppassword -e "drop database data_miner_test; create database data_miner_test charset utf8"}
$stderr.puts "Running `#{cmd}`..."
system cmd
$stderr.puts "Done."

require 'active_record'
require 'logger'
ActiveRecord::Base.logger = Logger.new $stderr
# ActiveRecord::Base.logger.level = Logger::INFO
ActiveRecord::Base.logger.level = Logger::DEBUG
ActiveRecord::Base.establish_connection(
  'adapter' => 'mysql2',
  'database' => 'data_miner_test',
  'username' => 'root',
  'password' => 'password'
)

require 'data_miner'
DataMiner::Run.auto_upgrade!
