require 'spec_helper'

class PetTest1 < ActiveRecord::Base
  self.primary_key = "name"
  col :name
  col :favorite_food
  data_miner do
    process :auto_upgrade!
    import("A list of pets", :url => "file://#{Pet::PETS}") do
      key :name
      store :favorite_food
    end
    test "Jerry likes cheese" do
      expect(PetTest1.find('Jerry').favorite_food).to eq 'cheese'
    end
  end
end

class PetTest2 < ActiveRecord::Base
  self.primary_key = "name"
  col :name
  col :favorite_food
  data_miner do
    process :auto_upgrade!
    import("A list of pets", :url => "file://#{Pet::PETS}") do
      key :name
      store :favorite_food
    end
    test "Jerry likes veggies" do
      expect(PetTest2.find('Jerry').favorite_food).to eq 'veggies'
    end
  end
end

class PetTest3 < ActiveRecord::Base
  self.primary_key = "name"
  col :name
  col :favorite_food
  data_miner do
    process :auto_upgrade!
    import("A list of pets", :url => "file://#{Pet::PETS}") do
      key :name
      store :favorite_food
    end
    test "First few have somebody named Pierre", after: 2 do
      expect(PetTest3.count).to eq 2
      expect(PetTest3.where(name: 'Pierre').count).to be > 0
    end
  end
end

class PetTest4 < ActiveRecord::Base
  self.primary_key = "name"
  col :name
  col :favorite_food
  data_miner do
    process :auto_upgrade!
    import("A list of pets", :url => "file://#{Pet::PETS}") do
      key :name
      store :favorite_food
    end
    test "First few have somebody named Johnny", after: 2 do
      expect(PetTest4.count).to eq 2 # that's where we are
      expect(PetTest4.where(name: 'Johnny').count).to be > 0
    end
  end
end

$pet_test_5_i = 0
class PetTest5 < ActiveRecord::Base
  self.primary_key = "name"
  col :name
  col :favorite_food
  data_miner do
    process :auto_upgrade!
    import("A list of pets", :url => "file://#{Pet::PETS}") do
      key :name
      store :favorite_food
    end
    test "Everybody has a name", every: 2 do
      $pet_test_5_i += 1
      expect(PetTest5.count).to eq $pet_test_5_i*2
      expect(PetTest5.where(name: nil).count).to be 0
    end
  end
end

$pet_test_6_i = 0
class PetTest6 < ActiveRecord::Base
  self.primary_key = "name"
  col :name
  col :favorite_food
  data_miner do
    process :auto_upgrade!
    import("A list of pets", :url => "file://#{Pet::PETS}") do
      key :name
      store :favorite_food
    end
    test "Everybody has a favorite food", every: 2 do
      $pet_test_6_i += 1
      expect(PetTest6.count).to eq $pet_test_6_i*2
      expect(PetTest6.where(favorite_food: nil).count).to be 0
    end
  end
end

describe DataMiner::Step::Test do
  it "keeps going if it passes" do
    PetTest1.run_data_miner!
    expect(PetTest1.count).to be > 0
  end
  it "stops on failure" do
    expect { PetTest2.run_data_miner! }.to raise_error(/Jerry.*veggies/)
    expect(PetTest2.count).to be > 0 # still populated tho
  end
  it "can be run in the middle of the previous step" do
    PetTest3.run_data_miner!
    expect(PetTest3.count).to be > 0
  end
  it "can be run in the middle of the previous step - failing" do
    expect { PetTest4.run_data_miner! }.to raise_error(/First few.*Johnny/)
    expect(PetTest4.count).to be 2 # stopped after 2
  end
  it "can be run every 2" do
    PetTest5.run_data_miner!
    expect($pet_test_5_i).to eq 2
    expect(PetTest5.count).to be 5
  end
  it "can be run every 2 - failing" do
    expect { PetTest6.run_data_miner! }.to raise_error(/Everybody has a favorite food/)
    expect($pet_test_6_i).to eq 2
    expect(PetTest6.count).to be $pet_test_6_i*2
  end
end
