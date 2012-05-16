# -*- encoding: utf-8 -*-
require 'helper'

describe DataMiner::Run::ColumnStatistic do
  describe "when advanced statistics are enabled" do
    before do
      DataMiner.per_column_statistics = true
      Pet.delete_all
      DataMiner::Run.delete_all
      DataMiner::Run::ColumnStatistic.delete_all
    end

    after do
      DataMiner.per_column_statistics = false
    end

    it "keeps null count" do
      Pet.run_data_miner!

      Pet.data_miner_runs.first.column_statistics_for(:breed_id, :before).null_count.must_equal 0
      Pet.data_miner_runs.first.column_statistics_for(:breed_id, :after).null_count.must_equal 1

      Pet.data_miner_runs.first.column_statistics_for(:command_phrase, :before).null_count.must_equal 0
      Pet.data_miner_runs.first.column_statistics_for(:command_phrase, :after).null_count.must_equal 0
    end

    it "keeps max and min (as strings)" do
      Pet.run_data_miner!
      Pet.data_miner_runs.first.column_statistics_for(:age, :before).max.must_equal 'nil'
      Pet.data_miner_runs.first.column_statistics_for(:age, :after).max.must_equal '17'
    end

    it "keeps average and stddev" do
      Pet.run_data_miner!

      Pet.data_miner_runs.first.column_statistics_for(:age, :before).average.must_be_nil
      Pet.data_miner_runs.first.column_statistics_for(:age, :after).average.must_equal 7.0

      Pet.data_miner_runs.first.column_statistics_for(:age, :before).standard_deviation.must_be_nil
      Pet.data_miner_runs.first.column_statistics_for(:age, :after).standard_deviation.must_equal 5.8737
    end
  end
end
