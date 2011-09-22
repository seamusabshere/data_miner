require 'loose_tight_dictionary'

class Aircraft < ActiveRecord::Base
  set_primary_key :icao_code
  set_table_name 'aircraft'

  def self.bts_dictionary
    @_dictionary ||= LooseTightDictionary.new RemoteTable.new(:url => 'http://www.bts.gov/programs/airline_information/accounting_and_reporting_directives/csv/number_260.csv', :select => lambda { |record| record['Aircraft Type'].to_i.between?(1, 998) and record['Manufacturer'].present? }),
                                              :tightenings  => RemoteTable.new(:url => 'http://spreadsheets.google.com/pub?key=tiS_6CCDDM_drNphpYwE_iw&single=true&gid=0&output=csv', :headers => false),
                                              :identities   => RemoteTable.new(:url => 'http://spreadsheets.google.com/pub?key=tiS_6CCDDM_drNphpYwE_iw&single=true&gid=3&output=csv', :headers => false),
                                              :blockings    => RemoteTable.new(:url => 'http://spreadsheets.google.com/pub?key=tiS_6CCDDM_drNphpYwE_iw&single=true&gid=4&output=csv', :headers => false),
                                              :left_reader  => lambda { |record| record['Manufacturer'] + ' ' + record['Model'] },
                                              :right_reader => lambda { |record| record['Manufacturer'] + ' ' + record['Long Name'] }
  end

  class BtsAircraftTypeCodeMatcher
    def match(left_record)
      right_record = Aircraft.bts_dictionary.left_to_right left_record
      right_record['Aircraft Type'] if right_record
    end
  end
  
  class BtsNameMatcher
    def match(left_record)
      right_record = Aircraft.bts_dictionary.left_to_right left_record
      right_record['Manufacturer'] + ' ' + right_record['Long Name'] if right_record
    end
  end
  
  class Guru
    # for errata
    def is_attributed_to_boeing?(row)
      row['Manufacturer'] =~ /BOEING/i
    end
    
    def is_not_attributed_to_airbus?(row)
      row['Manufacturer'] =~ /AIRBUS/i
    end
    
    def is_attributed_to_cessna?(row)
      row['Manufacturer'] =~ /CESSNA/i
    end
    
    def is_attributed_to_fokker?(row)
      row['Manufacturer'] =~ /FOKKER/i
    end
    
    def is_not_attributed_to_aerospatiale?(row)
      not row['Manufacturer'] =~ /AEROSPATIALE/i
    end
    
    def is_not_attributed_to_cessna?(row)
      not row['Manufacturer'] =~ /CESSNA/i
    end
    
    def is_not_attributed_to_learjet?(row)
      not row['Manufacturer'] =~ /LEAR/i
    end
    
    def is_not_attributed_to_dehavilland?(row)
      not row['Manufacturer'] =~ /DE ?HAVILLAND/i
    end
    
    def is_not_attributed_to_mcdonnell_douglas?(row)
      not row['Manufacturer'] =~ /MCDONNELL DOUGLAS/i
    end
    
    def is_not_a_dc_plane?(row)
      not row['Model'] =~ /DC/i
    end
    
    def is_a_crj_900?(row)
      row['Designator'].downcase == 'crj9'
    end
  end
  
  data_miner do
    # ('A'..'Z').each do |letter|
    # Note: for the purposes of testing, only importing "D"
    %w{ D }.each do |letter|
      import("ICAO codes starting with letter #{letter} used by the FAA",
              :url => "http://www.faa.gov/air_traffic/publications/atpubs/CNT/5-2-#{letter}.htm",
              :encoding => 'windows-1252',
              :errata => { :url => 'http://spreadsheets.google.com/pub?key=tObVAGyqOkCBtGid0tJUZrw', :responder => 'Aircraft::Guru' },
              :row_xpath => '//table/tr[2]/td/table/tr',
              :column_xpath => 'td') do
        key 'icao_code', :field_name => 'Designator'
        store 'bts_name', :matcher => Aircraft::BtsNameMatcher.new, :nullify => true
        store 'bts_aircraft_type_code', :matcher => Aircraft::BtsAircraftTypeCodeMatcher.new, :nullify => true
        store 'manufacturer_name', :field_name => 'Manufacturer', :nullify => true
        store 'name', :field_name => 'Model', :nullify => true
      end
      
      import 'Brighter Planet aircraft class codes',
             :url => 'http://static.brighterplanet.com/science/data/transport/air/bts_aircraft_type/bts_aircraft_types-brighter_planet_aircraft_classes.csv' do
        key   'bts_aircraft_type_code', :field_name => 'bts_aircraft_type'
        store 'brighter_planet_aircraft_class_code', :nullify => true
      end
    end
  end
end

