# -*- encoding: utf-8 -*-
require 'helper'

describe DataMiner do
  describe "when used to import example data about pets" do
    before do
      Pet.delete_all
      DataMiner::Run.delete_all
      DataMiner::Run::ColumnStatistic.delete_all
    end
    it "it does not depend on mass-assignment" do
      lambda do
        Pet.new(:name => 'hello').save!
      end.must_raise(ActiveModel::MassAssignmentSecurity::Error)
      lambda do
        Pet.new(:color_id => 'hello').save!
      end.must_raise(ActiveModel::MassAssignmentSecurity::Error)
      lambda do
        Pet.new(:age => 'hello').save!
      end.must_raise(ActiveModel::MassAssignmentSecurity::Error)
    end
    it "is idempotent given a key" do
      Pet.run_data_miner!
      first_count = Pet.count
      Pet.run_data_miner!
      Pet.count.must_equal first_count
    end
    it "can map fields in the source file to columns in the database" do
      Pet.run_data_miner!
      Pet.find('Jerry').breed_id.must_equal 'Beagle'
    end
    it "can use a dictionary to translate source data" do
      Pet.run_data_miner!
      Pet.find('Jerry').color_id.must_equal 'brown/black'
    end
    it "refreshes the dictionary for every run" do
      Pet.run_data_miner!
      Pet.find('Jerry').color_id.must_equal 'brown/black'
      begin
        FileUtils.mv COLOR_DICTIONARY_ENGLISH, "#{COLOR_DICTIONARY_ENGLISH}.bak"
        FileUtils.cp COLOR_DICTIONARY_SPANISH, COLOR_DICTIONARY_ENGLISH # oops! somebody swapped in a spanish dictionary
        Pet.run_data_miner!
        Pet.find('Jerry').color_id.must_equal 'morron/negro'
      ensure
        FileUtils.mv "#{COLOR_DICTIONARY_ENGLISH}.bak", COLOR_DICTIONARY_ENGLISH
      end
    end
    it "refreshes the data source for every run" do
      Pet.run_data_miner!
      Pet.find('Jerry').breed_id.must_equal 'Beagle'
      begin
        FileUtils.mv PETS, "#{PETS}.bak"
        FileUtils.cp PETS_FUNNY, PETS # oops! somebody swapped in a funny data source
        Pet.run_data_miner!
        Pet.find('Jerry').breed_id.must_equal 'Badger'
      ensure
        FileUtils.mv "#{PETS}.bak", PETS
      end
    end
    it "provides :run_data_miner_on_parent_associations!" do
      Pet.run_data_miner!
      Pet.find('Jerry').breed.must_equal Breed.find('Beagle')
    end
    it "runs class methods" do
      Breed.run_data_miner!
      Breed.find('Beagle').average_age.must_equal((5+2)/2.0)
    end
    it "deals with commas from numerical values" do
      Pet.run_data_miner!
      Pet.find('Amigo').age.must_equal 6205
    end
    it "performs unit conversions" do
      Pet.run_data_miner!
      Pet.find('Pierre').weight.must_be_close_to(4.4.pounds.to(:kilograms), 0.00001)
    end
    it "sets units" do
      Pet.run_data_miner!
      Pet.find('Pierre').age_units.must_equal 'years'
      Pet.find('Pierre').weight_units.must_equal 'kilograms'
      Pet.find('Pierre').height_units.must_equal 'centimetres'
    end
    it "always nullifies numeric columns when blank/nil is the input" do
      Pet.run_data_miner!
      Pet.find('Amigo').weight.must_be_nil
    end
    it "doesn't nullify string columns by default" do
      Pet.run_data_miner!
      Pet.find('Amigo').command_phrase.must_equal ''
      Pet.find('Johnny').command_phrase.must_equal ''
    end
    it "nullifies string columns on demand" do
      Pet.run_data_miner!
      Pet.find('Jerry').favorite_food.must_equal 'cheese'
      Pet.find('Johnny').favorite_food.must_be_nil
    end
    it "doesn't set units if the input was blank/null" do
      Pet.run_data_miner!
      Pet.find('Amigo').weight.must_be_nil
      Pet.find('Amigo').weight_units.must_be_nil
    end
    it "keeps a row count before and after" do
      Pet.run_data_miner!
      Pet.data_miner_runs.first.row_count_before.must_equal 0
      Pet.data_miner_runs.first.row_count_after.must_equal 5
    end
  end
end
