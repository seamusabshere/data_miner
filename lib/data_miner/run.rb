require 'aasm'
require 'active_record_inline_schema'

class DataMiner
  # A record of what happened when you ran a data miner script.
  #
  # To create the table, use +DataMiner::Run.auto_upgrade!+, possibly in +db/seeds.rb+ or a database migration.
  class Run < ::ActiveRecord::Base
    class << self
      # If a previous run died, you may find yourself getting +LockMethod::Locked+ exceptions.
      # 
      # @param [String] model_names What locks to clear.
      #
      # @return [nil]
      def clear_locks(model_names = DataMiner.model_names)
        model_names.each do |model_name|
          dummy = new
          dummy.model_name = model_name
          dummy.lock_method_clear :perform
        end
        nil
      end
    end

    # Raise this exception to skip the current run without causing it to fail.
    #
    # @example Avoid running certain data miner scripts too often (because they take too long).
    #   class FlightSegment < ActiveRecord::Base
    #     data_miner do
    #       [...]
    #       process "don't run this more than once an hour" do
    #         if (last_ran_at = data_miner_runs.first(:order => 'created_at DESC').try(:created_at)) and (Time.now.utc - last_ran_at) < 3600
    #           raise DataMiner::Run::Skip
    #         end
    #       end
    #       [...]
    #     end
    #   end
    class Skip < ::Exception
    end

    INITIAL_STATE = :limbo

    self.table_name = 'data_miner_runs'

    col :model_name
    col :aasm_state
    col :created_at, :type => :datetime
    col :stopped_at, :type => :datetime
    col :updated_at, :type => :datetime
    col :error, :type => :text

    include ::AASM
    aasm_initial_state INITIAL_STATE
    aasm_state :limbo
    aasm_state :skipped
    aasm_state :succeeded
    aasm_state :failed
    aasm_event(:succeed) { transitions :from => :limbo, :to => :succeeded }
    aasm_event(:skip)    { transitions :from => :limbo, :to => :skipped }
    aasm_event(:fail)    { transitions :from => :limbo, :to => :failed }

    validates_presence_of :model_name

    # @private
    def perform
      save!
      begin
        catch :data_miner_succeed do
          yield
        end
        succeed!
      rescue Skip
        skip!
      rescue
        self.error = "#{$!.message}\n#{$!.backtrace.join("\n")}"
        fail!
        raise $!
      ensure
        self.stopped_at = ::Time.now
        save!
        DataMiner.logger.info %{[data_miner] #{model_name} #{aasm_current_state.to_s.upcase} (#{(stopped_at-created_at).round(2)}s)}
      end
      self
    end
    lock_method :perform

    # @private
    def as_lock
      database_name = Run.connection.instance_variable_get(:@config).try(:[], :database)
      [database_name, model_name]
    end
  end
end
