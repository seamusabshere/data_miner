require_relative '../helper'
init_database(:alchemist)
init_pet
require 'test/unit/assertions'
include Test::Unit::Assertions

Pet.run_data_miner!
assert_in_delta Pet.find('Pierre').weight, 4.4.pounds.to.kilograms.to_f, 0.00001
