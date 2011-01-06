require 'test_helper'

class DataMiner::VerifyTest < Test::Unit::TestCase
  context '#run' do
    setup do
      @run = Object.new
      check = lambda do
        assert true
      end
      @verify = DataMiner::Verify.new Aircraft.new.data_miner_base, 1,
        'verification of engine type', check
    end
    should 'raise an exception if the verification block fails through exception' do
      @verify.check = lambda do
        assert false
      end
      assert_raise(DataMiner::VerificationFailed) { @verify.run @run }
    end
    should 'raise an exception if the result of the verification block is false' do
      @verify.check = lambda do
        false
      end
      assert_raise(DataMiner::VerificationFailed) { @verify.run @run }
    end
    should 'return true if the verification block succeeds' do
      assert @verify.run(@run)
    end
  end
end
