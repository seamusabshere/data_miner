$:.push File.dirname(__FILE__)
require 'helper'

TestDatabase.load_models

class TestDataMinerAttribute < Test::Unit::TestCase
  context '#value_from_row' do
    setup do
      @airport = Airport.new
    end
    context 'nullify is true' do
      setup do
        @attribute = DataMiner::Attribute.new @airport, 'latitude', :nullify => true
      end
      should 'return nil if field is blank' do
        assert_nil @attribute.value_from_row(
          'name' => 'DTW',
          'city' => 'Warren',
          'country_name' => 'US',
          'latitude' => '',
          'longitude' => ''
        )
      end
      should 'return the value if field is not blank' do
        assert_equal '12.34', @attribute.value_from_row(
          'name' => 'DTW',
          'city' => 'Warren',
          'country_name' => 'US',
          'latitude' => '12.34',
          'longitude' => ''
        )
      end
    end
    context 'nullify is false' do
      setup do
        @attribute = DataMiner::Attribute.new @airport, 'latitude'
      end
      should 'return the value if field is not blank' do
        assert_equal '12.34', @attribute.value_from_row(
          'name' => 'DTW',
          'city' => 'Warren',
          'country_name' => 'US',
          'latitude' => '12.34',
          'longitude' => ''
        )
      end
      should 'return blank if field is blank' do
        assert_equal '', @attribute.value_from_row(
          'name' => 'DTW',
          'city' => 'Warren',
          'country_name' => 'US',
          'latitude' => '',
          'longitude' => ''
        )
      end
    end
  end
  
  context '#set_record_from_row' do
    setup do
      @automobile_fuel_type = AutomobileFuelType.new
    end
    context 'nullify is true, wants units' do
      setup do
        @attribute = DataMiner::Attribute.new @automobile_fuel_type, 'annual_distance', :nullify => true, :units_field_name => 'annual_distance_units'
      end
      should 'set value and units to nil if field is blank' do
        @attribute.set_record_from_row(@automobile_fuel_type,
          'name' => 'electricity',
          'annual_distance' => '',
          'annual_distance_units' => ''
        )
        assert_nil @automobile_fuel_type.annual_distance
        assert_nil @automobile_fuel_type.annual_distance_units
      end
      should 'set value and units if field is not blank' do
        @attribute.set_record_from_row(@automobile_fuel_type,
          'name' => 'electricity',
          'annual_distance' => '100.0',
          'annual_distance_units' => 'kilometres'
        )
        assert_equal 100.0, @automobile_fuel_type.annual_distance
        assert_equal 'kilometres', @automobile_fuel_type.annual_distance_units
      end
    end
    
    context 'nullify is false, wants units' do
      setup do
        @attribute = DataMiner::Attribute.new @automobile_fuel_type, 'annual_distance', :units_field_name => 'annual_distance_units'
      end
      should 'set value and units to blank if field is blank' do
        @attribute.set_record_from_row(@automobile_fuel_type,
          'name' => 'electricity',
          'annual_distance' => '',
          'annual_distance_units' => ''
        )
        assert_equal 0.0, @automobile_fuel_type.annual_distance
        assert_equal '', @automobile_fuel_type.annual_distance_units
      end
      should 'set value and units if field is not blank' do
        @attribute.set_record_from_row(@automobile_fuel_type,
          'name' => 'electricity',
          'annual_distance' => '100.0',
          'annual_distance_units' => 'kilometres'
        )
        assert_equal 100.0, @automobile_fuel_type.annual_distance
        assert_equal 'kilometres', @automobile_fuel_type.annual_distance_units
      end
    end
  end
end
