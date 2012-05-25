require_relative './helper'

describe 'DataMiner unit conversion' do
  it 'performs no conversions by default' do
    output = `ruby #{File.expand_path('../support/data_miner_without_unit_converter.rb', __FILE__)}`
    assert_equal 0, $?.to_i, output
  end
  it 'can convert with alchemist' do
    output = `ruby #{File.expand_path('../support/data_miner_with_alchemist.rb', __FILE__)}`
    assert_equal 0, $?.to_i, output
  end
  it 'can convert with conversions' do
    output = `ruby #{File.expand_path('../support/data_miner_with_conversions.rb', __FILE__)}`
    assert_equal 0, $?.to_i, output
  end
end
