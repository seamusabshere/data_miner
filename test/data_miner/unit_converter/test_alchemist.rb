require 'helper'

describe 'DataMiner::UnitConverter::Alchemist' do
  before do
    DataMiner.unit_converter = :alchemist
  end

  describe '#convert' do
    it 'converts a value from one unit to another' do
      DataMiner.unit_converter.convert 3.5, :kilograms, :pounds
    end
  end
end
