require 'helper'

describe 'DataMiner unit conversion' do
  it "blows up if you don't specify a converter" do
    output = `ruby -I#{File.dirname(__FILE__)} #{File.expand_path('../support/data_miner_without_unit_converter.rb', __FILE__)}`
    refute $?.success?, output
  end
  it 'can convert with alchemist' do
    output = `ruby -I#{File.dirname(__FILE__)} #{File.expand_path('../support/data_miner_with_alchemist.rb', __FILE__)}`
    assert $?.success?, output
  end
  it 'can convert with conversions' do
    output = `ruby -I#{File.dirname(__FILE__)} #{File.expand_path('../support/data_miner_with_conversions.rb', __FILE__)}`
    assert $?.success?, output
  end
end
