# -*- encoding: utf-8 -*-
require 'helper'
init_database
init_models

describe DataMiner do
  describe "when used to import example data about pets" do
    before do
      Pet.delete_all
      Pet2.delete_all
      Pet3.delete_all
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
    it "properly interprets numbers using comma or period separators" do
      Pet.run_data_miner!
      Pet.find('Pierre').height.must_equal 3000.5
      Pet.find('Jerry').height.must_equal 3000.0
      Pet.find('Amigo').height.must_equal 300.5
      Pet.find('Johnny').height.must_equal 4000.0
    end
    it "performs unit conversions" do
      Pet.run_data_miner!
      Pet.find('Pierre').weight.must_be_close_to 1.9958 # 4.4 pounds in kilograms
    end
    it "doesn't convert nil to 0 when converting units" do
      Pet.run_data_miner!
      Pet.find('Nemo').age.must_be_nil
    end
    it "sets units" do
      Pet.run_data_miner!
      Pet.find('Pierre').age_units.must_equal 'years'
      Pet.find('Pierre').weight_units.must_equal 'kilograms'
      Pet.find('Pierre').height_units.must_equal 'millimetres'
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
    it "can import based on keys other than the primary key" do
      Pet2.run_data_miner!
      Pet2.find('Jerry').breed_id.must_equal 'Beagle-Basset'
    end
    it "dies if a column specified in an import step doesn't exist" do
      lambda do
        Pet3.run_data_miner!
      end.must_raise RuntimeError, /exist/i
    end
  end

  describe 'when the key attribute is not defined' do
    class PetFunny < ActiveRecord::Base
      self.primary_key = false
      col :name
      col :breed
      col :color

      data_miner do
        import 'without a key', url: "file://#{PETS_FUNNY}" do
          store :name
          store :breed
          store :color
        end
      end
    end
    PetFunny.auto_upgrade!

    before { PetFunny.delete_all }

    it 'imports the example data' do
      PetFunny.run_data_miner!
      PetFunny.must_be :exists?
    end

    it 'imports new example data for each run' do
      PetFunny.run_data_miner!
      first_count = PetFunny.count

      PetFunny.run_data_miner!
      PetFunny.count.must_equal first_count * 2
    end
  end
end
