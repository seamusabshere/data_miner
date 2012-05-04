class DataMiner
  class Step
    # A step that executes a single class method on the model or an arbitrary code block.
    #
    # Create these by calling +process+ inside a +data_miner+ block.
    #
    # @see DataMiner::ActiveRecordClassMethods#data_miner Overview of how to define data miner scripts inside of ActiveRecord models.
    # @see DataMiner::Script#process Creating a process step by calling DataMiner::Script#process from inside a data miner script
    class Process < Step
      # @private
      attr_reader :script

      # The method to be called on the model class.
      # @return [Symbol]
      attr_reader :method_id

      # A description of what the block does. Doesn't exist when a single class method is specified using a Symbol.
      # @return [String]
      attr_reader :description

      # The block of arbitrary code to be run.
      # @return [Proc]
      attr_reader :blk

      alias :block_description :description

      # @private
      def initialize(script, method_id_or_description, ignored_options = {}, &blk)
        @script = script
        if block_given?
          @description = method_id_or_description
          @blk = blk
        else
          @description = method_id_or_description
          @method_id = method_id_or_description
        end
      end
      
      # @private
      def perform
        DataMiner::Script.uniq do
          if blk
            model.instance_eval(&blk)
          else
            model.send method_id
          end
        end
        nil
      end
    end
  end
end
