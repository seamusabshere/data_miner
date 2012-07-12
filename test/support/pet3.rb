class Pet3 < ActiveRecord::Base
  col :a
  data_miner do
    process :auto_upgrade!
    import("A list of pets", :url => "file://#{PETS}") do
      key :b, :field_name => 'name'
    end
  end
end
