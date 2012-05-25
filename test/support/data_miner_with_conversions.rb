require_relative '../helper'

require 'conversions'
Conversions.register :years, :years, 1

init_database(:conversions)
init_pet
require 'test/unit/assertions'
include Test::Unit::Assertions

Pet.run_data_miner!
assert_in_delta Pet.find('Pierre').weight, 4.4.pounds.to(:kilograms), 0.00001
