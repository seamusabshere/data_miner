PETS = File.expand_path('../pets.csv', __FILE__)
PETS_FUNNY = File.expand_path('../pets_funny.csv', __FILE__)
COLOR_DICTIONARY_ENGLISH = File.expand_path('../pet_color_dictionary.en.csv', __FILE__)
COLOR_DICTIONARY_SPANISH = File.expand_path('../pet_color_dictionary.es.csv', __FILE__)

class Pet < ActiveRecord::Base
  self.primary_key = "name"
  col :name
  col :breed_id
  col :color_id
  col :age, :type => :integer
  col :weight, :type => :float
  col :height, :type => :float
  col :favorite_food
  col :command_phrase
  belongs_to :breed
  data_miner do
    process :auto_upgrade!
    process :run_data_miner_on_parent_associations!
    import("A list of pets", :url => "file://#{PETS}") do
      key :name
      store :age
      store :breed_id, :field_name => :breed, :nullify_blank_strings => true
      store :color_id, :field_name => :color, :dictionary => { :url => "file://#{COLOR_DICTIONARY_ENGLISH}", :input => :input, :output => :output }
      store :weight
      store :favorite_food, :nullify_blank_strings => true
      store :command_phrase
      store :height
    end
  end
end
