require 'rubygems'
require 'test/unit'
require 'shoulda'
require 'ruby-debug'

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))
require 'data_miner'

ActiveRecord::Base.establish_connection(
  'adapter' => 'mysql',
  'database' => 'data_miner_test',
  'username' => 'root',
  'password' => ''
)

ActiveSupport::Inflector.inflections do |inflect|
  inflect.uncountable 'aircraft'
end

class Test::Unit::TestCase
end

ActiveRecord::Schema.define(:version => 20090819143429) do
  create_table "t100_flight_segments", :force => true, :options => 'ENGINE=InnoDB default charset=utf8', :id => false do |t|
    t.integer  "departures_performed"
    t.integer  "payload"
    t.integer  "seats"
    t.integer  "passengers"
    t.integer  "freight"
    t.integer  "mail"
    t.integer  "ramp_to_ramp"
    t.integer  "air_time"
    t.float    "load_factor"
    t.float    "freight_share"
    t.integer  "distance"
    t.integer  "departures_scheduled"
    t.string   "unique_carrier"
    t.integer  "dot_airline_id"
    t.string   "unique_carrier_name"
    t.string   "unique_carrier_entity"
    t.string   "region"
    t.string   "carrier"
    t.string   "carrier_name"
    t.integer  "carrier_group"
    t.integer  "carrier_group_new"
    t.string   "origin_airport_iata"
    t.string   "origin_city_name"
    t.integer  "origin_city_num"
    t.string   "origin_state_abr"
    t.string   "origin_state_fips"
    t.string   "origin_state_nm"
    t.string   "origin_country_iso_3166"
    t.string   "origin_country_name"
    t.integer  "origin_wac"
    t.string   "dest_airport_iata"
    t.string   "dest_city_name"
    t.integer  "dest_city_num"
    t.string   "dest_state_abr"
    t.string   "dest_state_fips"
    t.string   "dest_state_nm"
    t.string   "dest_country_iso_3166"
    t.string   "dest_country_name"
    t.integer  "dest_wac"
    t.integer  "bts_aircraft_group"
    t.integer  "bts_aircraft_type"
    t.integer  "bts_aircraft_config"
    t.integer  "year"
    t.integer  "quarter"
    t.integer  "month"
    t.integer  "bts_distance_group"
    t.string   "bts_service_class"
    t.string   "data_source"
    t.float    "seats_per_departure"
    
    t.string 'payload_units'
    t.string 'freight_units'
    t.string 'mail_units'
    t.string 'distance_units'
    
    t.datetime "created_at"
    t.datetime "updated_at"
    
    t.string   "row_hash"
    t.integer 'data_miner_touch_count'
    t.integer 'data_miner_last_run_id'
  end
  execute 'ALTER TABLE t100_flight_segments ADD PRIMARY KEY (row_hash);'
  
  create_table 'badly_cloned_airports', :force => true, :options => 'ENGINE=InnoDB default charset=utf8', :id => false do |t|
    t.string 'placeholder'
  end
  
  create_table 'airports', :force => true, :options => 'ENGINE=InnoDB default charset=utf8', :id => false do |t|
    t.string   'iata_code'
    t.string   'name'
    t.string   'city'
    t.string   'country_name'
    t.float    'latitude'
    t.float    'longitude'
    t.datetime 'created_at'
    t.datetime 'updated_at'
    t.integer 'data_miner_touch_count'
    t.integer 'data_miner_last_run_id'
  end
  execute 'ALTER TABLE airports ADD PRIMARY KEY (iata_code);'
  
  create_table "countries", :force => true, :options => 'ENGINE=InnoDB default charset=utf8', :id => false do |t|
    t.string   "iso_3166"
    t.string   "name"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer 'data_miner_touch_count'
    t.integer 'data_miner_last_run_id'
  end
  execute "ALTER TABLE countries ADD PRIMARY KEY (iso_3166);"
  
  create_table "census_regions", :force => true, :options => 'ENGINE=InnoDB default charset=utf8', :id => false do |t|
    t.integer  "number"
    t.string   "name"
    t.datetime "updated_at"
    t.datetime "created_at"
    t.integer 'data_miner_touch_count'
    t.integer 'data_miner_last_run_id'
  end
  execute "ALTER TABLE census_regions ADD PRIMARY KEY (number);"
  
  create_table 'census_divisions', :force => true, :options => 'ENGINE=InnoDB default charset=utf8', :id => false do |t|
    t.integer  'number'
    t.string   'name'
    t.datetime 'updated_at'
    t.datetime 'created_at'
    t.string   'census_region_name'
    t.integer  'census_region_number'
    
    t.integer 'data_miner_touch_count'
    t.integer 'data_miner_last_run_id'
  end
  execute 'ALTER TABLE census_divisions ADD PRIMARY KEY (number);'
  
  create_table 'crosscalling_census_divisions', :force => true, :options => 'ENGINE=InnoDB default charset=utf8', :id => false do |t|
    t.integer  'number'
    t.string   'name'
    t.datetime 'updated_at'
    t.datetime 'created_at'
    t.string   'census_region_name'
    t.integer  'census_region_number'
    
    t.integer 'data_miner_touch_count'
    t.integer 'data_miner_last_run_id'
  end
  execute 'ALTER TABLE crosscalling_census_divisions ADD PRIMARY KEY (number);'
  
  create_table "automobile_variants", :force => true, :options => 'ENGINE=InnoDB default charset=utf8', :id => false do |t|
    t.float    "fuel_efficiency_city"
    t.float    "fuel_efficiency_highway"
    t.string   "make_name"
    t.string   "model_name"
    t.string   "year"
    t.string   "fuel_type_code"
    t.datetime "updated_at"
    t.datetime "created_at"
    t.string   "transmission"
    t.string   "drive"
    t.boolean  "turbo"
    t.boolean  "supercharger"
    t.integer  "cylinders"
    t.float    "displacement"
    t.float    "raw_fuel_efficiency_city"
    t.float    "raw_fuel_efficiency_highway"
    t.integer  "carline_mfr_code"
    t.integer  "vi_mfr_code"
    t.integer  "carline_code"
    t.integer  "carline_class_code"
    t.boolean  "injection"
    t.string   "carline_class_name"
    t.string   "speeds"
    
    t.string 'raw_fuel_efficiency_highway_units'
    t.string 'raw_fuel_efficiency_city_units'
    t.string 'fuel_efficiency_highway_units'
    t.string 'fuel_efficiency_city_units'
    
    t.string   "row_hash"
    t.integer 'data_miner_touch_count'
    t.integer 'data_miner_last_run_id'
  end
  execute "ALTER TABLE automobile_variants ADD PRIMARY KEY (row_hash);"
  
  create_table "automobile_fuel_types", :force => true, :options => 'ENGINE=InnoDB default charset=utf8', :id => false do |t|
    t.string   "name"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.float    "emission_factor"
    t.float    "annual_distance"
    t.string   "code"
    t.integer 'data_miner_touch_count'
    t.integer 'data_miner_last_run_id'
  end
  execute "ALTER TABLE automobile_fuel_types ADD PRIMARY KEY (code);"

  create_table "residential_energy_consumption_survey_responses", :options => 'ENGINE=InnoDB default charset=utf8', :id => false, :force => true do |t|
    t.integer  "department_of_energy_identifier"

    t.string   "residence_class"
    t.date     "construction_year"
    t.string   "construction_period"
    t.string   "urbanity"
    t.string   "dishwasher_use"
    t.string   "central_ac_use"
    t.string   "window_ac_use"
    t.string   "clothes_washer_use"
    t.string   "clothes_dryer_use"

    t.integer "census_division_number"
    t.string "census_division_name"
    t.integer "census_region_number"
    t.string "census_region_name"
    
    t.float    "rooms"
    t.float    "floorspace"
    t.integer  "residents"
    t.boolean  "ownership"
    t.boolean  "thermostat_programmability"
    t.integer  "refrigerator_count"
    t.integer  "freezer_count"    
    t.float    "annual_energy_from_fuel_oil_for_heating_space"
    t.float    "annual_energy_from_fuel_oil_for_heating_water"
    t.float    "annual_energy_from_fuel_oil_for_appliances"
    t.float    "annual_energy_from_natural_gas_for_heating_space"
    t.float    "annual_energy_from_natural_gas_for_heating_water"
    t.float    "annual_energy_from_natural_gas_for_appliances"
    t.float    "annual_energy_from_propane_for_heating_space"
    t.float    "annual_energy_from_propane_for_heating_water"
    t.float    "annual_energy_from_propane_for_appliances"
    t.float    "annual_energy_from_wood"
    t.float    "annual_energy_from_kerosene"
    t.float    "annual_energy_from_electricity_for_clothes_driers"
    t.float    "annual_energy_from_electricity_for_dishwashers"
    t.float    "annual_energy_from_electricity_for_freezers"
    t.float    "annual_energy_from_electricity_for_refrigerators"
    t.float    "annual_energy_from_electricity_for_air_conditioners"
    t.float    "annual_energy_from_electricity_for_heating_space"
    t.float    "annual_energy_from_electricity_for_heating_water"
    t.float    "annual_energy_from_electricity_for_other_appliances"
    t.float    "weighting"
    t.float    "lighting_use"
    t.float    "lighting_efficiency"
    t.integer  "heating_degree_days"
    t.integer  "cooling_degree_days"
    t.integer  "total_rooms"
    t.integer  "bathrooms"
    t.integer  "halfbaths"
    t.integer  "heated_garage"
    t.integer  "attached_1car_garage"
    t.integer  "detached_1car_garage"
    t.integer  "attached_2car_garage"
    t.integer  "detached_2car_garage"
    t.integer  "attached_3car_garage"
    t.integer  "detached_3car_garage"
    t.integer  "lights_on_1_to_4_hours"
    t.integer  "efficient_lights_on_1_to_4_hours"
    t.integer  "lights_on_4_to_12_hours"
    t.integer  "efficient_lights_on_4_to_12_hours"
    t.integer  "lights_on_over_12_hours"
    t.integer  "efficient_lights_on_over_12_hours"
    t.integer  "outdoor_all_night_lights"
    t.integer  "outdoor_all_night_gas_lights"
    
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer 'data_miner_touch_count'
    t.integer 'data_miner_last_run_id'
  end
  execute "ALTER TABLE residential_energy_consumption_survey_responses ADD PRIMARY KEY (department_of_energy_identifier);"
  
  create_table 'aircraft', :force => true, :options => 'ENGINE=InnoDB default charset=utf8', :id => false do |t|
    t.string 'icao_code'
    t.string   'name'
    t.string   'manufacturer_name'

    %w{pair_distance longest_subsequence longest_substring jaro jarowinkler levenshtein}.each do |n|
      # t.string   "#{n}_bts_aircraft_type_code"
      t.string   "#{n}_bts_name"
      # t.string   "#{n}_bts_manufacturer_name"
    end

    # t.string   'brighter_planet_aircraft_class_code'
    # t.float    'm3'
    # t.float    'm2'
    # t.float    'm1'
    # t.float    'endpoint_fuel'
    # t.string   'bts_begin_date'
    # t.string   'bts_end_date'
    t.datetime 'updated_at'
    t.datetime 'created_at'
    t.integer  'data_miner_touch_count'
    t.integer  'data_miner_last_run_id'
  end
  execute 'ALTER TABLE aircraft ADD PRIMARY KEY (icao_code);'
end

DataMiner::Run.create_tables
