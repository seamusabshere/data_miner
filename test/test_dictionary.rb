$:.push File.dirname(__FILE__)
require 'helper'

class TestDataMinerDictionary < Test::Unit::TestCase
  context 'case sensitive' do
    setup do
      options = {
        :input => 'name',
        :output => 'iso_3166_code',
        :url => "file://#{File.expand_path ::File.dirname(__FILE__)}/support/countries.csv"
      }
      @dict = DataMiner::Dictionary.new DataMiner.recursively_stringify_keys(options)
    end
    should 'find "Germany"' do
      assert_equal @dict.lookup("Germany"), 'DE'
    end
    should 'not find "GERMANY" or "germany"' do
      assert_nil @dict.lookup("GERMANY")
      assert_nil @dict.lookup("germany")
    end
  end
  context 'case insensitive' do
    setup do
      options = {
        :input => 'name',
        :output => 'iso_3166_code',
        :url => "file://#{File.expand_path ::File.dirname(__FILE__)}/support/countries.csv",
        :case_insensitive => true
      }
      @dict = DataMiner::Dictionary.new DataMiner.recursively_stringify_keys(options)
    end
    should 'find "Germany"' do
      assert_equal @dict.lookup("Germany"), 'DE'
    end
    should 'not also find "GERMANY" and "germany"' do
      assert_equal @dict.lookup("GERMANY"), 'DE'
      assert_equal @dict.lookup("germany"), 'DE'
    end
  end
end
