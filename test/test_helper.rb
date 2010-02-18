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
  end
  execute "ALTER TABLE airports ADD PRIMARY KEY (iata_code);"
  
  create_table "countries", :force => true, :options => 'ENGINE=InnoDB default charset=utf8', :id => false do |t|
    t.string   "iso_3166"
    t.string   "name"
    t.datetime "created_at"
    t.datetime "updated_at"
  end
  execute "ALTER TABLE countries ADD PRIMARY KEY (iso_3166);"
  
  create_table "census_regions", :force => true, :options => 'ENGINE=InnoDB default charset=utf8', :id => false do |t|
    t.string   "name"
    t.datetime "updated_at"
    t.datetime "created_at"
    t.integer  "number"
  end
  execute "ALTER TABLE census_regions ADD PRIMARY KEY (number);"
  
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
  end
  execute "ALTER TABLE automobile_variants ADD PRIMARY KEY (row_hash);"
  
  create_table "automobile_fuel_types", :force => true, :options => 'ENGINE=InnoDB default charset=utf8', :id => false do |t|
    t.string   "name"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.float    "emission_factor"
    t.float    "annual_distance"
    t.string   "code"
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
  end
  execute "ALTER TABLE automobile_make_years ADD PRIMARY KEY (row_hash);"

  create_table "automobile_makes", :force => true, :options => 'ENGINE=InnoDB default charset=utf8', :id => false do |t|
    t.string   "name"
    t.datetime "updated_at"
    t.datetime "created_at"
    t.float    "fuel_efficiency"
    t.boolean  "major"
  end
  execute "ALTER TABLE automobile_makes ADD PRIMARY KEY (name);"

  create_table "automobile_model_years", :force => true, :options => 'ENGINE=InnoDB default charset=utf8', :id => false do |t|
    t.integer  "year"
    t.datetime "updated_at"
    t.datetime "created_at"
    t.float    "fuel_efficiency"
  end
  execute "ALTER TABLE automobile_model_years ADD PRIMARY KEY (year);"

  create_table "automobile_models", :force => true, :options => 'ENGINE=InnoDB default charset=utf8', :id => false do |t|
    t.string   "name"
    t.string   "automobile_make_id"
    t.datetime "updated_at"
    t.datetime "created_at"
    t.string   "row_hash"
  end
  execute "ALTER TABLE automobile_models ADD PRIMARY KEY (row_hash);"
end
