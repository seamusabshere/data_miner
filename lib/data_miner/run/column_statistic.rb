class DataMiner
  class Run < ::ActiveRecord::Base
    # If +DataMiner.per_column_statistics?+, this model keeps per-column stats like max, min, average, standard deviation, etc.
    #
    # Each +DataMiner::Run+ will have two of these for every column; an "initial" and a "final"
    class ColumnStatistic < ::ActiveRecord::Base
      class << self
        def take(run)
          unless table_exists?
            auto_upgrade!
          end
          model = run.model_name.constantize
          return unless model.table_exists?
          model.column_names.each do |column_name|
            column_statistic = new
            column_statistic.run = run
            column_statistic.model_name = run.model_name
            column_statistic.column_name = column_name
            column_statistic.take_statistics
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
      col :column_name
      col :null_count, :type => :integer
      col :zero_count, :type => :integer
      col :blank_count, :type => :integer
      col :max
      col :min
      col :average, :type => :float
      col :sum, :type => :float
      col :created_at, :type => :datetime
      add_index :run_id
      add_index :model_name

      # @private
      def take_statistics
        model = run.model_name.constantize

        self.null_count = model.where("#{model.connection.quote_column_name(column_name)} IS NULL").count
        
        self.max = calc(:MAX).inspect
        self.min = calc(:MIN).inspect

        column = model.columns_hash[column_name]
        if NUMERIC.include?(column.type)
          self.zero_count = model.where(column_name => 0).count
          self.average = calc :AVG
          self.sum = calc :SUM
        elsif column.type == :string
          self.blank_count = model.where("LENGTH(TRIM(#{model.connection.quote_column_name(column_name)})) = 0").count
        end
      end

      private

      def calc(operation)
        model = run.model_name.constantize
        model.connection.select_value "SELECT #{operation}(#{model.connection.quote_column_name(column_name)}) FROM #{model.quoted_table_name}"
      end
    end
  end
end
