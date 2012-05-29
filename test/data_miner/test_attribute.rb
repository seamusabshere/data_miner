require_relative '../helper'

describe DataMiner::Attribute do
  before do
    DataMiner.unit_converter = :alchemist
  end

  describe '#enforce_conversion_options' do
    it 'raises an error if no converter is set but options warrant conversion' do
      DataMiner.unit_converter = nil
      attribute = DataMiner::Attribute.new :foo, 'bar', :from_units => :pounds, :to_units => :kilograms
      assert_raise DataMiner::Attribute::NoConverterSet do
        attribute.send(:enforce_conversion_options)
      end
    end
    it 'does not raise an error if a converter is set and options warrant conversion' do
      attribute = DataMiner::Attribute.new :foo, 'bar', :from_units => :pounds, :to_units => :kilograms
      assert_nothing_raised do
        attribute.send(:enforce_conversion_options)
      end
    end
    it 'does not raise an error if a converter is not set and no conversion options' do
      DataMiner.unit_converter = nil
      attribute = DataMiner::Attribute.new :foo, 'bar'
      assert_nothing_raised do
        attribute.send(:enforce_conversion_options)
      end
    end
  end

  describe '#convert?' do
    it 'returns true if a converter and from_units are set' do
      attribute = DataMiner::Attribute.new :foo, 'bar', :from_units => :pounds, :to_units => :kilograms
      assert attribute.send(:convert?)
    end
    it 'returns true if a converter and units_field_name are set' do
      attribute = DataMiner::Attribute.new :foo, 'bar', :units_field_name => 'bar'
      assert attribute.send(:convert?)
    end
    it 'returns true if a converter and units_field_number are set' do
      attribute = DataMiner::Attribute.new :foo, 'bar', :units_field_number => 3
      assert attribute.send(:convert?)
    end
    it 'returns false if there is no converter' do
      DataMiner.unit_converter = nil
      attribute = DataMiner::Attribute.new :foo, 'bar', :from_units => :pounds, :to_units => :kilograms
      assert !attribute.send(:convert?)
    end
    it 'returns false if there is a converter but no units' do
      attribute = DataMiner::Attribute.new :foo, 'bar'
      assert !attribute.send(:convert?)
    end
  end
end
