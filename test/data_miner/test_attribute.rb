require 'helper'

describe DataMiner::Attribute do
  before do
    DataMiner.unit_converter = :alchemist
  end

  describe '#convert?' do
    it 'returns true if from_units is set' do
      attribute = DataMiner::Attribute.new :foo, 'bar', :from_units => :pounds, :to_units => :kilograms
      assert attribute.send(:convert?)
    end
    it 'returns true if to_units and units_field_name are set' do
      attribute = DataMiner::Attribute.new :foo, 'bar', :units_field_name => 'bar', :to_units => :kilograms
      assert attribute.send(:convert?)
    end
    it 'returns true if to_units and units_field_number are set' do
      attribute = DataMiner::Attribute.new :foo, 'bar', :units_field_number => 3, :to_units => :kilograms
      assert attribute.send(:convert?)
    end
    it 'returns false if units_field_name only is set' do
      attribute = DataMiner::Attribute.new :foo, 'bar', :units_field_name => 'bar'
      refute attribute.send(:convert?)
    end
    it 'returns false if units_field_number only is set' do
      attribute = DataMiner::Attribute.new :foo, 'bar', :units_field_number => 'bar'
      refute attribute.send(:convert?)
    end
    it 'raises if no converter and units are used' do
      DataMiner.unit_converter = nil
      lambda {
        DataMiner::Attribute.new :foo, 'bar', :from_units => :pounds, :to_units => :kilograms
      }.must_raise ArgumentError, /unit_converter/
    end
  end
end
