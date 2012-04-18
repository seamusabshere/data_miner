# -*- encoding: utf-8 -*-
require 'helper'

PETS = File.expand_path('../support/pets.csv', __FILE__)
PETS_FUNNY = File.expand_path('../support/pets_funny.csv', __FILE__)
COLOR_DICTIONARY_ENGLISH = File.expand_path('../support/pet_color_dictionary.en.csv', __FILE__)
COLOR_DICTIONARY_SPANISH = File.expand_path('../support/pet_color_dictionary.es.csv', __FILE__)
BREEDS = File.expand_path('../support/breeds.xls', __FILE__)

class Pet < ActiveRecord::Base
  self.primary_key = "name"
  col :name
  col :breed_id
  col :color_id
  col :age, :type => :integer
  belongs_to :breed
  data_miner do
    process :auto_upgrade!
    process :run_data_miner_on_parent_associations!
    import("A list of pets", :url => "file://#{PETS}") do
      key :name
      store :age
      store :breed_id, :field_name => :breed
      store :color_id, :field_name => :color, :dictionary => { :url => "file://#{COLOR_DICTIONARY_ENGLISH}", :input => :input, :output => :output }
    end
  end
end

class Breed < ActiveRecord::Base
  class << self
    def update_average_age!
      # make sure pet is populated
      Pet.run_data_miner!
      update_all %{breeds.average_age = (SELECT AVG(pets.age) FROM pets WHERE pets.breed_id = breeds.name)}
    end
  end
  self.primary_key = "name"
  col :name
  col :average_age, :type => :float
  data_miner do
    process :auto_upgrade!
    import("A list of breeds", :url => "file://#{BREEDS}") do
      key :name, :field_name => 'Breed name'
    end
    process :update_average_age!
  end
end

Pet.auto_upgrade!

describe DataMiner do
  describe "when used to import example data about pets" do
    before do
      Pet.delete_all
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
      Breed.find('Beagle').average_age.must_equal (5+2)/2.0
    end
  end
end
