require 'helper'

describe 'DataMiner::UnitConverter::Alchemist' do
  before do
    @original_converter = DataMiner.unit_converter
    DataMiner.unit_converter = :alchemist
  end

  after do
    DataMiner.unit_converter = @original_converter
  end

  describe '#convert' do
    it 'converts a value from one unit to another' do
      value = DataMiner.unit_converter.convert 3.5, :kilograms, :pounds
      assert value.is_a?(Float)
      value.must_be_close_to 7.71617918
    end
  end
end
