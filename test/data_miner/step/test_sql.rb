# -*- encoding: utf-8 -*-
require 'helper'
init_database

class BreedBlue < ActiveRecord::Base
  self.primary_key = 'name'
  data_miner do
    # sql dump specially prepared with:
    # mysqldump --compatible=ansi,mysql40 --skip-comments --skip-add-locks --user=root --password=password --default-character-set utf8 test_earth breeds > breeds.ansi.sql
    # gsed "s/\\\'/''/g" breeds.ansi.sql > test/support/breed_blues.sql
    sql "Brighter Planet's list of breeds", File.expand_path('../../../support/breed_blues.sql', __FILE__)
  end
end

describe DataMiner::Step::Sql do
  it "works" do
    BreedBlue.run_data_miner!
    BreedBlue.where(:name => 'Affenpinscher').count.must_equal 1
    BreedBlue.where(:name => 'Württemberger').count.must_equal 1
    BreedBlue.find('Afghan Hound').weight.must_be_close_to 24.9476
  end
end
