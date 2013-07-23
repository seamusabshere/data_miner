BREED_BY_LICENSE_NUMBER = File.expand_path('../breed_by_license_number.csv', __FILE__)

class Pet2 < ActiveRecord::Base
  self.primary_key = "name"
  col :name
  col :breed_id
  col :license_number, :type => :integer

  data_miner do
    process :auto_upgrade!
    process :run_data_miner_on_parent_associations!
    import("A list of pets", :url => "file://#{PETS}") do
      key :name
      store :license_number
    end
    import("Breed numbers based on license number", :url => "file://#{BREED_BY_LICENSE_NUMBER}") do
      key :license_number
      store :breed_id, :field_name => :breed
    end
  end
end
