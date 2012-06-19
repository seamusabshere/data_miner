BREEDS = File.expand_path('../breeds.xls', __FILE__)

class Breed < ActiveRecord::Base
  class << self
    def update_average_age!
      # make sure pet is populated
      Pet.run_data_miner!
      update_all %{"average_age" = (SELECT AVG("pets"."age") FROM "pets" WHERE "pets"."breed_id" = "breeds"."name")}
    end
  end
  self.primary_key = "name"
  col :name
  col :average_age, :type => :float
  data_miner do
    process :auto_upgrade!
    import("A list of breeds", :url => "file://#{BREEDS}") do
      key :name, :field_name => 'Breed name'
    end
    process :update_average_age!
  end
end
