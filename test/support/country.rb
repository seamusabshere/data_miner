class Country < ActiveRecord::Base
  self.primary_key =  :iso_3166
  
  data_miner do
    import 'The official ISO country list', :url => 'http://www.iso.org/iso/list-en1-semic-3.txt', :encoding => 'ISO-8859-1', :skip => 2, :headers => false, :delimiter => ';' do
      key 'iso_3166', :field_number => 1
      store 'name', :field_number => 0
    end
    
    import 'A Princeton dataset with better capitalization', :url => 'http://www.cs.princeton.edu/introcs/data/iso3166.csv' do
      key 'iso_3166', :field_name => 'country code'
      store 'name', :field_name => 'country'
    end
  end
end
