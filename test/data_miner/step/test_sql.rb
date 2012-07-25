# -*- encoding: utf-8 -*-
require 'helper'
init_database

class BreedBlue < ActiveRecord::Base
  self.table_name = 'breeds'
  self.primary_key = 'name'
  data_miner do
    sql "Brighter Planet's list of breeds (as a URL)", 'http://data.brighterplanet.com/breeds.sql'
  end
end

class BreedRed < ActiveRecord::Base
  self.table_name = 'breeds'
  self.primary_key = 'name'
  data_miner do
    sql "Brighter Planet's list of breeds (as a URL)", 'http://data.brighterplanet.com/breeds.sql'
    sql "Mess up weights", %{UPDATE breeds SET weight = 999}
  end
end

describe DataMiner::Step::Sql do
  before do
    BreedBlue.delete_all rescue nil
  end
  it "can be provided as a URL" do
    BreedBlue.run_data_miner!
    BreedBlue.where(:name => 'Affenpinscher').count.must_equal 1
    BreedBlue.where(:name => 'Württemberger').count.must_equal 1
    BreedBlue.find('Afghan Hound').weight.must_be_close_to 24.9476
  end
  it "can be provided as a string" do
    BreedRed.run_data_miner!
    BreedRed.where(:name => 'Affenpinscher').count.must_equal 1
    BreedRed.where(:name => 'Württemberger').count.must_equal 1
    BreedRed.find('Afghan Hound').weight.must_be_close_to 999
  end
end
