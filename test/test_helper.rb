require 'rubygems'
require 'test/unit'
require 'shoulda'
require 'sqlite3'

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))
require 'data_miner'

ActiveRecord::Base.establish_connection(
  'adapter' => 'sqlite3',
  'database' => 'test/test.sqlite3'
)

class Test::Unit::TestCase
end
