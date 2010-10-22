class AutomobileFuelType < ActiveRecord::Base
  set_primary_key :code
  
  data_miner do
    import(:url => 'http://www.fueleconomy.gov/FEG/epadata/00data.zip',
                :filename => 'Gd6-dsc.txt',
                :format => :fixed_width,
                :crop => 21..26, # inclusive
                :cut => '2-',
                :select => lambda { |row| /\A[A-Z]/.match row[:code] },
                :schema => [[ 'code',   2, { :type => :string }  ],
                            [ 'spacer', 2 ],
                            [ 'name',   52, { :type => :string } ]]) do
      key 'code'
      store 'name'
    end

    import :url => 'http://static.brighterplanet.com/science/data/transport/automobiles/models_export/automobile_fuel_type.csv' do
      key 'code'
      store 'name'
      store 'annual_distance'
      store 'emission_factor'
    end

    # pull electricity emission factor from residential electricity
    import(:url => 'http://spreadsheets.google.com/pub?key=rukxnmuhhsOsrztTrUaFCXQ',
                :select => lambda { |row| row['code'] == 'El' }) do
      key 'code'
      store 'name'
      store 'emission_factor'
    end
    
    # still need distance estimate for electric cars
  end
  
  CODES = {
    :electricity => 'El',
    :diesel => 'D'
  }
end
