$:.push File.dirname(__FILE__)
require 'helper'

TestDatabase.load_models

class TappedAirport < ActiveRecord::Base
  self.primary_key =  :iata_code

  data_miner do
    tap "Brighter Planet's sanitized airports table", "http://carbon:neutral@data.brighterplanet.com:5001", :source_table_name => 'airports'
    # tap "Brighter Planet's sanitized airports table", "http://carbon:neutral@localhost:5000", :source_table_name => 'airports'
  end
end


class TestTap < Test::Unit::TestCase
  should "tap airports" do
    TappedAirport.run_data_miner!
    assert TappedAirport.count > 0
  end
end
