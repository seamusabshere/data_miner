# -*- encoding: utf-8 -*-
require 'helper'
init_database

describe DataMiner::Run::ColumnStatistic do
  describe "when advanced statistics are enabled" do
    before do
      DataMiner.per_column_statistics = true
      Pet.delete_all
      DataMiner::Run.delete_all
      DataMiner::Run::ColumnStatistic.delete_all
      Pet.run_data_miner!
    end

    after do
      DataMiner.per_column_statistics = false
    end

    it "keeps null count" do
      Pet.data_miner_runs.first.initial_column_statistics(:breed_id).null_count.must_equal 0
      Pet.data_miner_runs.first.final_column_statistics(:breed_id).null_count.must_equal 1

      Pet.data_miner_runs.first.initial_column_statistics(:command_phrase).null_count.must_equal 0
      Pet.data_miner_runs.first.final_column_statistics(:command_phrase).null_count.must_equal 0
    end

    it "keeps max and min (as strings)" do
      Pet.data_miner_runs.first.initial_column_statistics(:age).max.must_equal 'nil'
      Pet.data_miner_runs.first.final_column_statistics(:age).max.must_equal '17'
    end

    it "keeps average and sum" do
      Pet.data_miner_runs.first.initial_column_statistics(:age).average.must_be_nil
      Pet.data_miner_runs.first.final_column_statistics(:age).average.must_equal 7.0

      Pet.data_miner_runs.first.initial_column_statistics(:age).sum.must_be_nil
      Pet.data_miner_runs.first.final_column_statistics(:age).sum.must_equal 28.0
    end

    it "keeps blank (empty string) count" do
      Pet.data_miner_runs.first.initial_column_statistics(:command_phrase).blank_count.must_equal 0
      Pet.data_miner_runs.first.final_column_statistics(:command_phrase).blank_count.must_equal 3
    end

    it "keeps zero count" do
      Pet.data_miner_runs.first.initial_column_statistics(:age).zero_count.must_equal 0
      Pet.data_miner_runs.first.final_column_statistics(:age).zero_count.must_equal 0
    end

  end
end
