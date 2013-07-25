# -*- encoding: utf-8 -*-
require 'helper'
init_database

class StateBlue < ActiveRecord::Base
  self.table_name = 'states'
  self.primary_key = 'postal_abbreviation'
  data_miner do
    sql "Brighter Planet's list of states (as a URL)", 'http://data.brighterplanet.com/states.sql'
  end
end

class StateRed < ActiveRecord::Base
  self.table_name = 'states'
  self.primary_key = 'postal_abbreviation'
  data_miner do
    sql "Brighter Planet's list of states (as a URL)", 'http://data.brighterplanet.com/states.sql'
    sql "Mess up weights", %{UPDATE states SET name = 'Foobar'}
  end
end

describe DataMiner::Step::Sql do
  before do
    StateBlue.delete_all rescue nil
  end
  it "can be provided as a URL" do
    StateBlue.run_data_miner!
    StateBlue.where(:name => 'Wisconsin').count.must_equal 1
  end
  it "can be provided as a string" do
    StateRed.run_data_miner!
    StateRed.find('NJ').name.must_equal 'Foobar'
  end
end
