require_relative '../../helper'

describe 'DataMiner::UnitConverter::Conversions' do
  before do
    #DataMiner.unit_converter = :conversions
  end

  describe '#convert' do
    it 'converts a value from one unit to another' do
      # can't load both alchemist and conversions in same test run
      # see test/test_unit_conversion for coverage of this adapter
      #DataMiner.unit_converter.convert 3.5, :kilograms, :pounds
    end
  end
end
