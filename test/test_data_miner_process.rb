$:.push File.dirname(__FILE__)
require 'helper'

class TestDataMinerProcess < Test::Unit::TestCase
  context '#inspect' do
    setup do
      @config = DataMiner::Config.new 'foo'
    end
    should 'describe a block' do
      process = DataMiner::Process.new(@config, 'something cool') { }
      assert_match /something cool/, process.inspect
    end
    should 'describe a method' do
      process = DataMiner::Process.new @config, :something_cool
      assert_match /something_cool/, process.inspect
    end
  end
end
