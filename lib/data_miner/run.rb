require 'aasm'
require 'active_record_inline_schema'

class DataMiner
  class Run < ::ActiveRecord::Base
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
    end
    lock_method :perform

    def as_lock
      [Run.connection.current_database, model_name]
    end
  end
end
