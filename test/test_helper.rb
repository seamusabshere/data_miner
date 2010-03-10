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

class Test::Unit::TestCase
end

ActiveRecord::Schema.define(:version => 20090819143429) do
  create_table "airports", :force => true, :options => 'ENGINE=InnoDB default charset=utf8', :id => false do |t|
    t.string  "country_id"
    
    t.string   "iata_code"
    t.string   "name"
    t.string   "city"
    t.string   "country_name"
    t.float    "latitude"
    t.float    "longitude"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer 'data_miner_touch_count'
    t.integer 'data_miner_last_run_id'
  end
  execute "ALTER TABLE airports ADD PRIMARY KEY (iata_code);"
  
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
  
  create_table "automobile_variants", :force => true, :options => 'ENGINE=InnoDB default charset=utf8', :id => false do |t|
    t.string   "automobile_make_id"
    t.string   "automobile_model_id"
    t.string   "automobile_model_year_id"
    t.string   "automobile_fuel_type_id"
    
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

  create_table "automobile_make_fleet_years", :force => true, :options => 'ENGINE=InnoDB default charset=utf8', :id => false do |t|
    t.string   "automobile_make_id"
    t.string   "automobile_model_year_id"
    t.integer  "automobile_make_year_id"

    t.string   "fleet"
    t.string   "make_name"
    t.string   "year"
    t.float    "fuel_efficiency"
    t.integer  "volume"
    t.datetime "created_at"
    t.datetime "updated_at"

    t.string   "row_hash"
    t.integer 'data_miner_touch_count'
    t.integer 'data_miner_last_run_id'
  end
  execute "ALTER TABLE automobile_make_fleet_years ADD PRIMARY KEY (row_hash);"

  create_table "automobile_make_years", :force => true, :options => 'ENGINE=InnoDB default charset=utf8', :id => false do |t|
    t.integer  "automobile_make_id" # user-defined
    t.integer  "automobile_model_year_id" # user-defined
    t.datetime "created_at"
    t.datetime "updated_at"
    t.float    "fuel_efficiency"
    t.integer  "volume"
    t.string   "row_hash"
    t.integer 'data_miner_touch_count'
    t.integer 'data_miner_last_run_id'
  end
  execute "ALTER TABLE automobile_make_years ADD PRIMARY KEY (row_hash);"

  create_table "automobile_makes", :force => true, :options => 'ENGINE=InnoDB default charset=utf8', :id => false do |t|
    t.string   "name"
    t.datetime "updated_at"
    t.datetime "created_at"
    t.float    "fuel_efficiency"
    t.boolean  "major"
    t.integer 'data_miner_touch_count'
    t.integer 'data_miner_last_run_id'
  end
  execute "ALTER TABLE automobile_makes ADD PRIMARY KEY (name);"

  create_table "automobile_model_years", :force => true, :options => 'ENGINE=InnoDB default charset=utf8', :id => false do |t|
    t.integer  "year"
    t.datetime "updated_at"
    t.datetime "created_at"
    t.float    "fuel_efficiency"
    t.integer 'data_miner_touch_count'
    t.integer 'data_miner_last_run_id'
  end
  execute "ALTER TABLE automobile_model_years ADD PRIMARY KEY (year);"

  create_table "automobile_models", :force => true, :options => 'ENGINE=InnoDB default charset=utf8', :id => false do |t|
    t.string   "name"
    t.string   "automobile_make_id"
    t.datetime "updated_at"
    t.datetime "created_at"
    t.string   "row_hash"
    t.integer 'data_miner_touch_count'
    t.integer 'data_miner_last_run_id'
  end
  execute "ALTER TABLE automobile_models ADD PRIMARY KEY (row_hash);"
  
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

  # add_index "residence_survey_responses", ["annual_energy_from_electricity_for_clothes_driers", "annual_energy_from_electricity_for_dishwashers", "annual_energy_from_electricity_for_freezers", "annual_energy_from_electricity_for_refrigerators", "annual_energy_from_electricity_for_air_conditioners", "annual_energy_from_electricity_for_heating_space", "annual_energy_from_electricity_for_heating_water", "annual_energy_from_electricity_for_other_appliances", "weighting", "floorspace", "residents", "heating_degree_days", "census_region_id"], :name => "index_residence_survey_responses_on_annu3501626657"
  # add_index "residence_survey_responses", ["annual_energy_from_electricity_for_clothes_driers", "weighting", "floorspace"], :name => "index_residence_survey_responses_on_annu1433274229"
  # add_index "residence_survey_responses", ["annual_energy_from_electricity_for_clothes_driers", "weighting", "residence_clothes_drier_use_id"], :name => "index_residence_survey_responses_on_annu1262382397"
  # add_index "residence_survey_responses", ["annual_energy_from_electricity_for_dishwashers", "weighting", "floorspace", "residents", "heating_degree_days", "census_region_id"], :name => "index_residence_survey_responses_on_annu4218458677"
  # add_index "residence_survey_responses", ["annual_energy_from_electricity_for_dishwashers", "weighting", "floorspace"], :name => "index_residence_survey_responses_on_annu119061746"
  # add_index "residence_survey_responses", ["annual_energy_from_electricity_for_dishwashers", "weighting", "residence_dishwasher_use_id"], :name => "index_residence_survey_responses_on_annu3439036757"
  # add_index "residence_survey_responses", ["annual_energy_from_electricity_for_freezers", "weighting", "floorspace", "residents", "heating_degree_days", "census_region_id"], :name => "index_residence_survey_responses_on_annu3327447874"
  # add_index "residence_survey_responses", ["annual_energy_from_electricity_for_freezers", "weighting", "floorspace"], :name => "index_residence_survey_responses_on_annu1386319236"
  # add_index "residence_survey_responses", ["annual_energy_from_electricity_for_refrigerators", "weighting", "floorspace", "residents", "heating_degree_days", "census_region_id"], :name => "index_residence_survey_responses_on_annu73542686"
  # add_index "residence_survey_responses", ["annual_energy_from_electricity_for_refrigerators", "weighting", "floorspace"], :name => "index_residence_survey_responses_on_annu3936186192"
  # add_index "residence_survey_responses", ["annual_energy_from_fuel_oil_for_heating_space", "annual_energy_from_fuel_oil_for_heating_water", "annual_energy_from_fuel_oil_for_appliances", "weighting", "floorspace", "residents", "heating_degree_days", "census_region_id"], :name => "index_residence_survey_responses_on_annu2746016586"
  # add_index "residence_survey_responses", ["annual_energy_from_kerosene", "weighting", "floorspace", "residents", "heating_degree_days", "census_region_id"], :name => "index_residence_survey_responses_on_annu2598214"
  # add_index "residence_survey_responses", ["annual_energy_from_kerosene", "weighting", "floorspace"], :name => "index_residence_survey_responses_on_annu502197058"
  # add_index "residence_survey_responses", ["annual_energy_from_natural_gas_for_heating_space", "annual_energy_from_natural_gas_for_heating_water", "annual_energy_from_natural_gas_for_appliances", "weighting", "floorspace", "residents", "heating_degree_days", "census_region_id"], :name => "index_residence_survey_responses_on_annu830199308"
  # add_index "residence_survey_responses", ["annual_energy_from_propane_for_heating_space", "annual_energy_from_propane_for_heating_water", "annual_energy_from_propane_for_appliances", "weighting", "floorspace", "residents", "heating_degree_days", "census_region_id"], :name => "index_residence_survey_responses_on_annu4097984181"
  # add_index "residence_survey_responses", ["annual_energy_from_wood", "weighting", "floorspace", "residents", "heating_degree_days", "census_region_id"], :name => "index_residence_survey_responses_on_annu250862876"
  # add_index "residence_survey_responses", ["annual_energy_from_wood", "weighting", "floorspace"], :name => "index_residence_survey_responses_on_annu3742395500"
  # add_index "residence_survey_responses", ["floorspace", "annual_energy_from_electricity_for_clothes_driers", "annual_energy_from_electricity_for_dishwashers", "annual_energy_from_electricity_for_freezers", "annual_energy_from_electricity_for_refrigerators", "annual_energy_from_electricity_for_air_conditioners", "annual_energy_from_electricity_for_heating_space", "annual_energy_from_electricity_for_heating_water", "annual_energy_from_electricity_for_other_appliances", "weighting"], :name => "index_residence_survey_responses_on_floo1081052200"
  # add_index "residence_survey_responses", ["floorspace", "annual_energy_from_fuel_oil_for_heating_space", "annual_energy_from_fuel_oil_for_heating_water", "annual_energy_from_fuel_oil_for_appliances", "weighting"], :name => "index_residence_survey_responses_on_floo2042532749"
  # add_index "residence_survey_responses", ["floorspace", "annual_energy_from_natural_gas_for_heating_space", "annual_energy_from_natural_gas_for_heating_water", "annual_energy_from_natural_gas_for_appliances", "weighting"], :name => "index_residence_survey_responses_on_floo4150514738"
  # add_index "residence_survey_responses", ["floorspace", "annual_energy_from_propane_for_heating_space", "annual_energy_from_propane_for_heating_water", "annual_energy_from_propane_for_appliances", "weighting"], :name => "index_residence_survey_responses_on_floo2054994085"
  # add_index "residence_survey_responses", ["floorspace", "construction_year", "residents", "heating_degree_days", "census_region_id", "residence_class_id", "ownership", "cooling_degree_days", "residence_urbanity_id"], :name => "index_residence_survey_responses_on_floo2191768676"
  # add_index "residence_survey_responses", ["floorspace", "construction_year", "residents", "heating_degree_days", "census_region_id", "residence_class_id", "ownership", "cooling_degree_days"], :name => "index_residence_survey_responses_on_floo1971465492"
  # add_index "residence_survey_responses", ["floorspace", "construction_year", "residents", "heating_degree_days", "census_region_id", "residence_class_id", "ownership"], :name => "index_residence_survey_responses_on_floo4007566201"
  # add_index "residence_survey_responses", ["floorspace", "construction_year", "residents", "heating_degree_days", "census_region_id", "residence_class_id"], :name => "index_residence_survey_responses_on_floo1574191187"
  # add_index "residence_survey_responses", ["floorspace", "construction_year", "residents", "heating_degree_days", "census_region_id"], :name => "index_residence_survey_responses_on_floo259916455"
  # add_index "residence_survey_responses", ["floorspace", "construction_year", "residents", "heating_degree_days"], :name => "index_residence_survey_responses_on_floo2330810762"
  # add_index "residence_survey_responses", ["floorspace", "construction_year", "residents"], :name => "index_residence_survey_responses_on_floo3429600394"
  # add_index "residence_survey_responses", ["floorspace", "construction_year"], :name => "index_residence_survey_responses_on_floo809808213"
  # add_index "residence_survey_responses", ["floorspace"], :name => "index_residence_survey_responses_on_floorspace"
  # add_index "residence_survey_responses", ["lighting_efficiency", "weighting", "floorspace"], :name => "index_residence_survey_responses_on_ligh1681825374"
  # add_index "residence_survey_responses", ["lighting_use", "weighting", "floorspace"], :name => "index_residence_survey_responses_on_ligh3781776396"
  # add_index "residence_survey_responses", ["refrigerator_count"], :name => "index_residence_survey_responses_on_refr2806359993"
  # add_index "residence_survey_responses", ["residence_clothes_drier_use_id"], :name => "index_residence_survey_responses_on_resi3713455541"
end
