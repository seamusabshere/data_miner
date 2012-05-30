require 'helper'

class MyPet < ActiveRecord::Base
  PETS = File.expand_path('../pets.csv', __FILE__)
  COLOR_DICTIONARY_ENGLISH = File.expand_path('../pet_color_dictionary.en.csv', __FILE__)

  self.primary_key = "name"
  col :name
  col :color_id
  col :age, :type => :integer
  col :age_units
  col :weight, :type => :float
  col :weight_units
  col :height, :type => :integer
  col :height_units
  col :favorite_food
  col :command_phrase

  data_miner do
    process :auto_upgrade!
    import("A list of pets", :url => "file://#{PETS}") do
      key :name
      store :age
      store :color_id, :field_name => :color, :dictionary => { :url => "file://#{COLOR_DICTIONARY_ENGLISH}", :input => :input, :output => :output }
      store :weight
      store :favorite_food, :nullify_blank_strings => true
      store :command_phrase
      store :height, :units => :centimetres
    end
  end
end

describe 'DataMiner with Conversions' do
  it 'happens when DataMiner.unit_converter is nil' do
    DataMiner.unit_converter.must_be_nil
  end

  it 'converts convertible units' do
    init_database(nil)
    MyPet.run_data_miner!
    MyPet.find('Pierre').weight.must_equal 4.4
  end

  it 'raises an error if conversions are attempted' do
    init_database(nil)
    lambda do
      init_models
      Pet.run_data_miner!
    end.must_raise DataMiner::Attribute::NoConverterSet
  end
end
