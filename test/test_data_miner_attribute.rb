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
end
