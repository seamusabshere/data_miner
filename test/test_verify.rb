require File.expand_path('helper', File.dirname(__FILE__))

class TestVerify < Test::Unit::TestCase
  context '#run' do
    setup do
      @run = Object.new
      check = lambda do
        true
      end
      @verify = DataMiner::Verify.new Aircraft.new.data_miner_config,
        'verification of engine type', &check
    end
    should 'raise an exception if the verification block fails through exception' do
      @verify.blk = lambda do
        assert false
      end
      assert_raise(DataMiner::VerificationFailed) { @verify.run }
    end
    should 'raise an exception if the result of the verification block is false' do
      @verify.blk = lambda do
        false
      end
      assert_raise(DataMiner::VerificationFailed) { @verify.run }
    end
    should 'return true if the verification block succeeds' do
      assert_nil @verify.run
    end
  end
end
