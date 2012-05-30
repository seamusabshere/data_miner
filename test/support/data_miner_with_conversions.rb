require 'helper'

require 'conversions'
Conversions.register :years, :years, 1

describe 'DataMiner with Conversions' do
  before do
    init_database(:conversions)
    init_models
    Pet.run_data_miner!
  end

  it 'converts convertible units' do
    Pet.find('Pierre').weight.must_be_close_to 4.4.pounds.to(:kilograms)
  end
end
