require 'helper'

describe 'DataMiner with Alchemist' do
  before do
    init_database
    init_models
    Pet.run_data_miner!
  end
end
