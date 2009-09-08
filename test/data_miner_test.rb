require 'test_helper'

ActiveRecord::Schema.define(:version => 20090819143429) do
  create_table "airports", :force => true do |t|
    t.string   "iata_code"
    t.string   "name"
    t.string   "city"
    t.integer  "country_id"
    t.float    "latitude"
    t.float    "longitude"
    t.datetime "created_at"
    t.datetime "updated_at"
  end
  create_table "countries", :force => true do |t|
    t.string   "iso_3166"
    t.string   "name"
    t.datetime "created_at"
    t.datetime "updated_at"
  end
end

class Country < ActiveRecord::Base
  mine_data do |step|
    # import country names and country codes
    step.import :url => 'http://www.cs.princeton.edu/introcs/data/iso3166.csv' do |attr|
      attr.key :iso_3166, :name_in_source => 'country code'
      attr.store :iso_3166, :name_in_source => 'country code'
      attr.store :name, :name_in_source => 'country'
    end
  end
end

class Airport < ActiveRecord::Base
  belongs_to :country
  mine_data do |step|
    # import airport iata_code, name, etc.
    step.import(:url => 'http://openflights.svn.sourceforge.net/viewvc/openflights/openflights/data/airports.dat', :headers => false) do |attr|
      attr.key :iata_code, :field_number => 3
      attr.store :name, :field_number => 0
      attr.store :city, :field_number => 1
      attr.store :country, :field_number => 2, :foreign_key => :name       # will use Country.find_by_name(X)
      attr.store :iata_code, :field_number => 3
      attr.store :latitude, :field_number => 5
      attr.store :longitude, :field_number => 6
    end
  end
end

DataMiner.enqueue do |queue|
  queue << Country
  queue << Airport
end

class DataMinerTest < Test::Unit::TestCase
  def teardown
    Airport.delete_all
    Country.delete_all
  end
  
  should "mine a single class" do
    Country.data_mine.mine
    assert_equal 'Uruguay', Country.find_by_iso_3166('UY').name
    assert_equal 0, Airport.count
  end
  
  should "mine a single class using the API" do
    DataMiner.mine :class_names => ['Country']
    assert_equal 'Uruguay', Country.find_by_iso_3166('UY').name
    assert_equal 0, Airport.count
  end
  
  should "mine all classes" do
    DataMiner.mine
    uy = Country.find_by_iso_3166('UY')
    assert_equal 'Uruguay', uy.name
    assert_equal uy, Airport.find_by_iata_code('MVD').country
  end
end
