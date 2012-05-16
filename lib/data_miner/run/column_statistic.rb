class DataMiner
  class Run < ::ActiveRecord::Base
    # If +DataMiner.per_column_statistics?+, this model keeps per-column stats like max, min, average, standard deviation, etc.
    #
    # Each +DataMiner::Run+ will have two of these for every column; a "before" and an "after".
    class ColumnStatistic < ::ActiveRecord::Base
      class << self
        # @private
        def before(run)
          period run, 'before'
        end

        # @private
        def after(run)
          period run, 'after'
        end

        private

        def period(run, period)
          unless table_exists?
            auto_upgrade!
          end
          model = run.model_name.constantize
          return unless model.table_exists?
          model.column_names.each do |column_name|
            column_statistic = new
            column_statistic.run = run
            column_statistic.model_name = run.model_name
            column_statistic.period = period
            column_statistic.column_name = column_name
            column_statistic.perform_calculations
            column_statistic.save!
          end
          nil
        end

      end

      NUMERIC = [
        :integer,
        :float,
        :decimal,
      ]

      self.table_name = 'data_miner_run_column_statistics'

      belongs_to :run, :class_name => 'DataMiner::Run'

      col :run_id, :type => :integer
      col :model_name
      col :period
      col :column_name
      col :null_count, :type => :integer
      col :max
      col :min
      col :average, :type => :float
      col :standard_deviation, :type => :float
      col :sum, :type => :float
      add_index :run_id
      add_index :model_name

      # @private
      def perform_calculations
        model = run.model_name.constantize

        self.null_count = model.where("#{model.connection.quote_column_name(column_name)} IS NULL").count
        self.max = calculate(:MAX).inspect
        self.min = calculate(:MIN).inspect

        column = model.columns_hash[column_name]
        if NUMERIC.include?(column.type)
          self.average = calculate :AVG
          self.standard_deviation = calculate :STDDEV
          self.sum = calculate :SUM
        end
      end

      private

      def calculate(operation)
        model = run.model_name.constantize
        model.connection.select_value "SELECT #{operation}(#{model.connection.quote_column_name(column_name)}) FROM #{model.quoted_table_name}"
      end
    end
  end
end
