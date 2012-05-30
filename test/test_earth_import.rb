# -*- encoding: utf-8 -*-
require 'helper'
init_database
init_models
require 'earth'

# use earth, which has a plethora of real-world data_miner blocks
Earth.init :locality, :pet, :load_data_miner => true, :apply_schemas => true

describe DataMiner do
  describe "being used by the Earth library's import steps" do
    describe "for pets" do
      it "can pull breed and species" do
        Breed.run_data_miner!
        Breed.find('Golden Retriever').species.must_equal Species.find('dog')
      end
    end
    describe "for localities" do
      it "can handle non-latin characters" do
        Country.run_data_miner!
        Country.find('DE').name.must_equal 'Germany'
        Country.find('AX').name.must_equal 'Åland Islands'
        Country.find('CI').name.must_equal "Côte d'Ivoire"
      end
    end
  end
end
