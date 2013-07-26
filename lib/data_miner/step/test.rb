require 'rspec-expectations'

class DataMiner
  class Step
    # A step that runs tests and stops the data miner on failures.
    #
    # Create these by calling +test+ inside a +data_miner+ block.
    #
    # @see DataMiner::ActiveRecordClassMethods#data_miner Overview of how to define data miner scripts inside of ActiveRecord models.
    # @see DataMiner::Script#test Creating a test step by calling DataMiner::Script#test from inside a data miner script
    class Test < Step
      include ::RSpec::Expectations
      include ::RSpec::Matchers

      # A description of what the block does. Doesn't exist when a single class method is specified using a Symbol.
      # @return [String]
      attr_reader :description

      # The block of arbitrary code to be run.
      # @return [Proc]
      attr_reader :blk

      # After how many rows of the previous step to run the tests.
      # @return [Numeric]
      attr_reader :after

      # Every how many rows to run tests
      # @return [Numeric]
      attr_reader :every

      alias :block_description :description

      # @private
      def initialize(script, description, settings, &blk)
        @script = script
        @description = description
        @blk = blk
        @after = settings[:after]
        @every = settings[:every]
        raise "can't do both after and every" if after and every
      end
      
      # @private
      def start
        if inline?
          eval_catching_errors
        end
        nil
      end

      def target?(step)
        !inline? and (step.pos == pos - 1)
      end

      def notify(step, count)
        if count % (after || every) == 0
          eval_catching_errors
          !after # if it's an after, return false, so that we stop getting informed
        else
          true
        end
      end

      private

      def inline?
        not (after or every)
      end

      def eval_catching_errors
        DataMiner::Script.uniq { instance_eval(&blk) }
      rescue ::RSpec::Expectations::ExpectationNotMetError
        raise RuntimeError, "FAILED: #{description} (#{$!.inspect})"
      end
    end
  end
end
