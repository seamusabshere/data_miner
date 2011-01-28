require File.expand_path('helper', File.dirname(__FILE__))

class TestDataMinerVerify < Test::Unit::TestCase
  context '#run' do
    should 'raise an exception if the verification block fails through exception' do
      raising_check = lambda { raise "boom" }
      verify = DataMiner::Verify.new Aircraft.new.data_miner_config, 'verification of engine type', &raising_check
      assert_raise(DataMiner::VerificationFailed) { verify.run }
    end
    should 'raise an exception if the result of the verification block is false' do
      failing_check = lambda { false }
      verify = DataMiner::Verify.new Aircraft.new.data_miner_config, 'verification of engine type', &failing_check
      assert_raise(DataMiner::VerificationFailed) { verify.run }
    end
    should 'return true if the verification block succeeds' do
      passing_check = lambda { true }
      verify = DataMiner::Verify.new Aircraft.new.data_miner_config, 'verification of engine type', &passing_check
      assert_nil verify.run
    end
  end
end
