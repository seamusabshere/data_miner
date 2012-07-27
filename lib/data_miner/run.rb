require 'aasm'
require 'active_record_inline_schema'

require 'data_miner/run/column_statistic'

class DataMiner
  # A record of what happened when you ran a data miner script.
  #
  # To create the table, use +DataMiner::Run.auto_upgrade!+, possibly in +db/seeds.rb+ or a database migration.
  class Run < ::ActiveRecord::Base
    class << self
      # If a previous run died and you have manually enabled locking, you may find yourself getting +LockMethod::Locked+ exceptions.
      #
      # @note Starting in 2.1.0, runs are no longer locked by default. This method remains in case you want to re-apply locking.
      # 
      # @param [String] model_names What locks to clear.
      #
      # @return [nil]
      #
      # @example Re-enable locking (since it was turned off by default in 2.1.0)
      #   require 'data_miner'
      #   require 'lock_method'
      #   DataMiner::Run.lock_method :start
      def clear_locks(model_names = DataMiner.model_names)
        return unless defined?(::LockMethod)
        model_names.each do |model_name|
          dummy = new
          dummy.model_name = model_name
          dummy.lock_method_clear :start
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
    col :row_count_before, :type => :integer
    col :row_count_after, :type => :integer
    add_index :model_name
    add_index :aasm_state

    validates_presence_of :model_name

    has_many :column_statistics, :class_name => 'DataMiner::Run::ColumnStatistic', :order => 'id ASC'

    include ::AASM
    aasm_initial_state INITIAL_STATE
    aasm_state :limbo
    aasm_state :skipped
    aasm_state :succeeded
    aasm_state :failed
    aasm_event(:succeed) { transitions :from => :limbo, :to => :succeeded }
    aasm_event(:skip)    { transitions :from => :limbo, :to => :skipped }
    aasm_event(:fail)    { transitions :from => :limbo, :to => :failed }

    # @private
    def start
      model = model_name.constantize
      if model.table_exists?
        self.row_count_before = model.count
      end
      save!
      if DataMiner.per_column_statistics?
        ColumnStatistic.take self
      end
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
        if model.connection.respond_to?(:schema_cache)
          model.connection.schema_cache.clear!
        end
        model.reset_column_information
        if model.table_exists?
          self.row_count_after = model.count
          if DataMiner.per_column_statistics?
            ColumnStatistic.take self
          end
        end
        self.stopped_at = ::Time.now.utc
        save!
        DataMiner.logger.info %{[data_miner] #{model_name} #{aasm_current_state.to_s.upcase} (#{(stopped_at-created_at).round(2)}s)}
      end
      self
    end

    # Get the column statistics for a particular column before this run started.
    #
    # @param [String] column_name The column you want to know about.
    #
    # @return [ColumnStatistic]
    def initial_column_statistics(column_name)
      column_statistics.where(:column_name => column_name.to_s).first
    end

    # Get the column statistics for a particular column after this run finished.
    #
    # @param [String] column_name The column you want to know about.
    #
    # @return [ColumnStatistic]
    def final_column_statistics(column_name)
      column_statistics.where(:column_name => column_name.to_s).last
    end

    # @private
    def as_lock
      database_name = Run.connection.instance_variable_get(:@config).try(:[], :database)
      [database_name, model_name]
    end
  end
end
