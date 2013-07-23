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
MiniTest::Reporters.use!

require 'active_record'
require 'logger'
ActiveRecord::Base.logger = Logger.new $stderr
ActiveRecord::Base.logger.level = Logger::INFO
# ActiveRecord::Base.logger.level = Logger::DEBUG

ActiveRecord::Base.mass_assignment_sanitizer = :strict

require 'data_miner'

def init_database
  case ENV['DATABASE']
  when /postgr/i
    system %{dropdb test_data_miner}
    system %{createdb test_data_miner}
    ActiveRecord::Base.establish_connection(
      'adapter' => 'postgresql',
      'encoding' => 'utf8',
      'database' => 'test_data_miner',
      'username' => `whoami`.chomp
    )
  when /sqlite/i
    ActiveRecord::Base.establish_connection(:adapter => "sqlite3", :database => ":memory:")
  else
    system %{mysql -u root -ppassword -e "DROP DATABASE test_data_miner"}
    system %{mysql -u root -ppassword -e "CREATE DATABASE test_data_miner CHARSET utf8"}
    ActiveRecord::Base.establish_connection(
      'adapter' => (RUBY_PLATFORM == 'java' ? 'mysql' : 'mysql2'),
      'encoding' => 'utf8',
      'database' => 'test_data_miner',
      'username' => 'root',
      'password' => 'password'
    )
  end
end

def init_models
  require 'support/breed'
  require 'support/pet'
  require 'support/pet2'
  require 'support/pet3'
  Pet.auto_upgrade!
  Pet2.auto_upgrade!
  Pet3.auto_upgrade!

  ActiveRecord::Base.descendants.each do |model|
    model.attr_accessible nil
  end
end
