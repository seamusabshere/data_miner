class Airport < ActiveRecord::Base
  self.primary_key =  :iata_code
  
  data_miner do
    import :url => 'https://openflights.svn.sourceforge.net/svnroot/openflights/openflights/data/airports.dat',
           :headers => false,
           :select => lambda { |row| row[4].present? } do
      key 'iata_code', :field_number => 4
      store 'name', :field_number => 1
      store 'city', :field_number => 2
      store 'country_name', :field_number => 3
      store 'latitude', :field_number => 6, :nullify => true
      store 'longitude', :field_number => 7, :nullify => true
    end
  end
end
