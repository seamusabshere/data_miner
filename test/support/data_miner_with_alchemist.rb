require 'helper'

describe 'DataMiner with Alchemist' do
  before do
    init_database(:alchemist)
    init_models
    Pet.run_data_miner!
  end

  it 'converts convertible units' do
    Pet.find('Pierre').weight.must_be_close_to 4.4.pounds.to.kilograms.to_f
  end
end
