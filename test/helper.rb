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

case ENV['DATABASE']
when /mysql/i
  bin = ENV['TEST_MYSQL_BIN'] || 'mysql'
  username = ENV['TEST_MYSQL_USERNAME'] || 'root'
  password = ENV['TEST_MYSQL_PASSWORD'] || 'password'
  database = ENV['TEST_MYSQL_DATABASE'] || 'data_miner_test'
  cmd = "#{bin} -u #{username} -p#{password}"
  `#{cmd} -e 'show databases'`
  unless $?.success?
    $stderr.puts "Skipping mysql tests because `#{cmd}` doesn't work"
    exit 0
  end
  system %{#{cmd} -e "drop database #{database}"}
  system %{#{cmd} -e "create database #{database}"}
  ActiveRecord::Base.establish_connection(
    'adapter' => (RUBY_PLATFORM == 'java' ? 'mysql' : 'mysql2'),
    'encoding' => 'utf8',
    'database' => database,
    'username' => username,
    'password' => password
  )
when /postgr/i
  createdb_bin = ENV['TEST_CREATEDB_BIN'] || 'createdb'
  dropdb_bin = ENV['TEST_DROPDB_BIN'] || 'dropdb'
  username = ENV['TEST_POSTGRES_USERNAME'] || `whoami`.chomp
  # password = ENV['TEST_POSTGRES_PASSWORD'] || 'password'
  database = ENV['TEST_POSTGRES_DATABASE'] || 'data_miner_test'
  system %{#{dropdb_bin} #{database}}
  system %{#{createdb_bin} #{database}}
  ActiveRecord::Base.establish_connection(
    'adapter' => 'postgresql',
    'encoding' => 'utf8',
    'database' => database,
    'username' => username
    # 'password' => password
  )
when /sqlite/i
  ActiveRecord::Base.establish_connection(:adapter => "sqlite3", :database => ":memory:")
else
  raise "don't know how to test against #{ENV['DATABASE']}"
end

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
  require 'support/pet2'
  Pet.auto_upgrade!
  Pet2.auto_upgrade!

  ActiveRecord::Base.descendants.each do |model|
    model.attr_accessible nil
  end
end
