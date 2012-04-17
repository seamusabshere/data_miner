require 'active_record_inline_schema'

class DataMiner
  class Run < ::ActiveRecord::Base
    class << self
      def stack
        @users ||= 0
        @stack ||= []
        @users += 1
        yield @stack
        @users -= 1
        if @users == 0
          @stack = nil
        end
      end
    end

    self.table_name = 'data_miner_runs'

    col :model_name
    col :killed, :type => :boolean
    col :skipped, :type => :boolean
    col :finished, :type => :boolean
    col :terminated_at, :type => :datetime
    col :created_at, :type => :datetime
    col :updated_at, :type => :datetime
    col :error, :type => :text

    validates_presence_of :model_name

    def perform(stack)
      return if stack.include? model_name
      stack << model_name
      self.killed = true
      save!
      begin
        yield
        self.finished = true
      rescue Finish
        self.finished = true
      rescue Skip
        self.skipped = true
      rescue
        self.error = "#{$!}\n#{$!.backtrace.join("\n")}"
        raise $!
      ensure
        self.terminated_at = ::Time.now
        self.killed = false
        save!
        DataMiner.logger.info "Performed #{inspect}"
      end
    end

    def model
      @model ||= model_name.constantize
    end
  end
end
