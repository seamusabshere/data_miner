require 'rubygems'
require 'bundler/setup'

if Bundler.definition.specs['ruby-debug19'].first or Bundler.definition.specs['ruby-debug'].first
  require 'ruby-debug'
end

require 'minitest/spec'
require 'minitest/autorun'
require 'minitest/reporters'
MiniTest::Unit.runner = MiniTest::SuiteRunner.new
MiniTest::Unit.runner.reporters << MiniTest::Reporters::SpecReporter.new

cmd = %{mysql -u root -ppassword -e "DROP DATABASE data_miner_test; CREATE DATABASE data_miner_test CHARSET utf8"}
$stderr.puts "Running `#{cmd}`..."
system cmd
$stderr.puts "Done."

require 'active_record'
require 'logger'
ActiveRecord::Base.logger = Logger.new $stderr
ActiveRecord::Base.logger.level = Logger::INFO
# ActiveRecord::Base.logger.level = Logger::DEBUG
ActiveRecord::Base.establish_connection(
  'adapter' => 'mysql2',
  'database' => 'data_miner_test',
  'username' => 'root',
  'password' => 'password'
)

ActiveRecord::Base.mass_assignment_sanitizer = :strict

require 'data_miner'
DataMiner::Run.auto_upgrade!
DataMiner::Run::ColumnStatistic.auto_upgrade!
DataMiner::Run.clear_locks

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
  col :age_units
  col :weight, :type => :float
  col :weight_units
  col :height, :type => :float
  col :height_units
  col :favorite_food
  col :command_phrase
  belongs_to :breed
  data_miner do
    process :auto_upgrade!
    process :run_data_miner_on_parent_associations!
    import("A list of pets", :url => "file://#{PETS}") do
      key :name
      store :age, :units_field_name => 'age_units'
      store :breed_id, :field_name => :breed, :nullify_blank_strings => true
      store :color_id, :field_name => :color, :dictionary => { :url => "file://#{COLOR_DICTIONARY_ENGLISH}", :input => :input, :output => :output }
      store :weight, :from_units => :pounds, :to_units => :kilograms
      store :favorite_food, :nullify_blank_strings => true
      store :command_phrase
      store :height, :units => :millimetres
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

ActiveRecord::Base.descendants.each do |model|
  model.attr_accessible nil
end

Pet.auto_upgrade!
