$:.push File.dirname(__FILE__)
require 'helper'

TestDatabase.load_models

class CensusRegion < ActiveRecord::Base
  set_primary_key :number

  data_miner do
    import :url => 'http://www.census.gov/popest/geographic/codes02.csv', :skip => 9, :select => lambda { |row| row['Region'].to_i > 0 and row['Division'].to_s.strip == 'X'} do
      key 'number', :field_name => 'Region'
      store 'name', :field_name => 'Name'
    end

    # pretend this is a different data source
    # fake! just for testing purposes
    import :url => 'http://www.census.gov/popest/geographic/codes02.csv', :skip => 9, :select => lambda { |row| row['Region'].to_i > 0 and row['Division'].to_s.strip == 'X'} do
      key 'number', :field_name => 'Region'
      store 'name', :field_name => 'Name'
    end
  end
end

# smaller than a region
class CensusDivision < ActiveRecord::Base
  set_primary_key :number

  data_miner do
    import :url => 'http://www.census.gov/popest/geographic/codes02.csv', :skip => 9, :select => lambda { |row| row['Division'].to_s.strip != 'X' and row['FIPS CODE STATE'].to_s.strip == 'X'} do
      key 'number', :field_name => 'Division'
      store 'name', :field_name => 'Name'
      store 'census_region_number', :field_name => 'Region'
      store 'census_region_name', :field_name => 'Region', :dictionary => { :input => 'number', :output => 'name', :url => 'http://data.brighterplanet.com/census_regions.csv' }
    end
  end
end

class CensusDivisionDeux < ActiveRecord::Base
  set_primary_key :number

  data_miner do
    import :url => 'http://www.census.gov/popest/geographic/codes02.csv', :skip => 9, :select => lambda { |row| row['Division'].to_s.strip != 'X' and row['FIPS CODE STATE'].to_s.strip == 'X'} do
      key 'number', :field_name => 'Division'
      store 'name', :field_name => 'Name'
      store 'census_region_number', :field_name => 'Region'
      store 'census_region_name', :field_name => 'Region', :dictionary => DataMiner::Dictionary.new(:input => 'number', :output => 'name', :url => 'http://data.brighterplanet.com/census_regions.csv')
    end
  end
end

class CrosscallingCensusRegion < ActiveRecord::Base
  set_primary_key :number

  has_many :crosscalling_census_divisions

  data_miner do
    process "derive ourselves from the census divisions table (i.e., cross call census divisions)" do
      CrosscallingCensusDivision.run_data_miner!
      connection.create_table :crosscalling_census_regions, :options => 'ENGINE=InnoDB default charset=utf8', :id => false, :force => true do |t|
        t.column :number, :integer
        t.column :name, :string
      end
      connection.execute 'ALTER TABLE crosscalling_census_regions ADD PRIMARY KEY (number);'
      connection.execute %{
        INSERT IGNORE INTO crosscalling_census_regions(number, name)
        SELECT crosscalling_census_divisions.census_region_number, crosscalling_census_divisions.census_region_name FROM crosscalling_census_divisions
      }
    end
  end
end

class CrosscallingCensusDivision < ActiveRecord::Base
  set_primary_key :number

  belongs_to :crosscalling_census_regions, :foreign_key => 'census_region_number'

  data_miner do
    import "get a list of census divisions and their regions", :url => 'http://www.census.gov/popest/geographic/codes02.csv', :skip => 9, :select => lambda { |row| row['Division'].to_s.strip != 'X' and row['FIPS CODE STATE'].to_s.strip == 'X'} do
      key 'number', :field_name => 'Division'
      store 'name', :field_name => 'Name'
      store 'census_region_number', :field_name => 'Region'
      store 'census_region_name', :field_name => 'Region', :dictionary => { :input => 'number', :output => 'name', :url => 'http://data.brighterplanet.com/census_regions.csv' }
    end

    process "make sure my parent object is set up (i.e., cross-call it)" do
      CrosscallingCensusRegion.run_data_miner!
    end
  end
end

class ResidentialEnergyConsumptionSurveyResponse < ActiveRecord::Base
  set_primary_key :department_of_energy_identifier

  data_miner do
    process 'Define some unit conversions' do
      Conversions.register :kbtus, :joules, 1_000.0 * 1_055.05585
      Conversions.register :square_feet, :square_metres, 0.09290304
    end

    # conversions are NOT performed here, since we first have to zero out legitimate skips
    # otherwise you will get values like "999 pounds = 453.138778 kilograms" (where 999 is really a legit skip)
    import 'RECs 2005 (but not converting units to metric just yet)', :url => 'http://www.eia.doe.gov/emeu/recs/recspubuse05/datafiles/RECS05alldata.csv' do
      key 'department_of_energy_identifier', :field_name => 'DOEID'

      store 'residence_class', :field_name => 'TYPEHUQ', :dictionary => { :input => 'Code', :output => 'Description', :url => 'http://github.com/brighterplanet/manually_curated_data/raw/master/typehuq/typehuq.csv' }
      store 'construction_year', :field_name => 'YEARMADE', :dictionary => { :input => 'Code', :sprintf => '%02d', :output => 'Date in the middle (synthetic)', :url => 'http://github.com/brighterplanet/manually_curated_data/raw/master/yearmade/yearmade.csv' }
      store 'construction_period', :field_name => 'YEARMADE', :dictionary => { :input => 'Code', :sprintf => '%02d', :output => 'Description', :url => 'http://github.com/brighterplanet/manually_curated_data/raw/master/yearmade/yearmade.csv' }
      store 'urbanity', :field_name => 'URBRUR', :dictionary => { :input => 'Code', :output => 'Description', :url => 'http://github.com/brighterplanet/manually_curated_data/raw/master/urbrur/urbrur.csv' }
      store 'dishwasher_use', :field_name => 'DWASHUSE', :dictionary => { :input => 'Code', :output => 'Description', :url => 'http://github.com/brighterplanet/manually_curated_data/raw/master/dwashuse/dwashuse.csv' }
      store 'central_ac_use', :field_name => 'USECENAC', :dictionary => { :input => 'Code', :output => 'Description', :url => 'http://github.com/brighterplanet/manually_curated_data/raw/master/usecenac/usecenac.csv' }
      store 'window_ac_use', :field_name => 'USEWWAC', :dictionary => { :input => 'Code', :output => 'Description', :url => 'http://github.com/brighterplanet/manually_curated_data/raw/master/usewwac/usewwac.csv' }
      store 'clothes_washer_use', :field_name => 'WASHLOAD', :dictionary => { :input => 'Code', :output => 'Description', :url => 'http://github.com/brighterplanet/manually_curated_data/raw/master/washload/washload.csv' }
      store 'clothes_dryer_use', :field_name => 'DRYRUSE', :dictionary => { :input => 'Code', :output => 'Description', :url => 'http://github.com/brighterplanet/manually_curated_data/raw/master/dryruse/dryruse.csv' }

      store 'census_division_number', :field_name => 'DIVISION'
      store 'census_division_name', :field_name => 'DIVISION', :dictionary => { :input => 'number', :output => 'name', :url => 'http://data.brighterplanet.com/census_divisions.csv' }
      store 'census_region_number', :field_name => 'DIVISION', :dictionary => { :input => 'number', :output => 'census_region_number', :url => 'http://data.brighterplanet.com/census_divisions.csv' }
      store 'census_region_name', :field_name => 'DIVISION', :dictionary => { :input => 'number', :output => 'census_region_name', :url => 'http://data.brighterplanet.com/census_divisions.csv' }

      store 'floorspace', :field_name => 'TOTSQFT'
      store 'residents', :field_name => 'NHSLDMEM'
      store 'ownership', :field_name => 'KOWNRENT'
      store 'thermostat_programmability', :field_name => 'PROTHERM'
      store 'refrigerator_count', :field_name => 'NUMFRIG'
      store 'freezer_count', :field_name => 'NUMFREEZ'
      store 'heating_degree_days', :field_name => 'HD65'
      store 'cooling_degree_days', :field_name => 'CD65'
      store 'annual_energy_from_fuel_oil_for_heating_space', :field_name => 'BTUFOSPH'
      store 'annual_energy_from_fuel_oil_for_heating_water', :field_name => 'BTUFOWTH'
      store 'annual_energy_from_fuel_oil_for_appliances', :field_name => 'BTUFOAPL'
      store 'annual_energy_from_natural_gas_for_heating_space', :field_name => 'BTUNGSPH'
      store 'annual_energy_from_natural_gas_for_heating_water', :field_name => 'BTUNGWTH'
      store 'annual_energy_from_natural_gas_for_appliances', :field_name => 'BTUNGAPL'
      store 'annual_energy_from_propane_for_heating_space', :field_name => 'BTULPSPH'
      store 'annual_energy_from_propane_for_heating_water', :field_name => 'BTULPWTH'
      store 'annual_energy_from_propane_for_appliances', :field_name => 'BTULPAPL'
      store 'annual_energy_from_wood', :field_name => 'BTUWOOD'
      store 'annual_energy_from_kerosene', :field_name => 'BTUKER'
      store 'annual_energy_from_electricity_for_clothes_driers', :field_name => 'BTUELCDR'
      store 'annual_energy_from_electricity_for_dishwashers', :field_name => 'BTUELDWH'
      store 'annual_energy_from_electricity_for_freezers', :field_name => 'BTUELFZZ'
      store 'annual_energy_from_electricity_for_refrigerators', :field_name => 'BTUELRFG'
      store 'annual_energy_from_electricity_for_air_conditioners', :field_name => 'BTUELCOL'
      store 'annual_energy_from_electricity_for_heating_space', :field_name => 'BTUELSPH'
      store 'annual_energy_from_electricity_for_heating_water', :field_name => 'BTUELWTH'
      store 'annual_energy_from_electricity_for_other_appliances', :field_name => 'BTUELAPL'
      store 'weighting', :field_name => 'NWEIGHT'
      store 'total_rooms', :field_name => 'TOTROOMS'
      store 'bathrooms', :field_name => 'NCOMBATH'
      store 'halfbaths', :field_name => 'NHAFBATH'
      store 'heated_garage', :field_name => 'GARGHEAT'
      store 'attached_1car_garage', :field_name => 'GARAGE1C'
      store 'detached_1car_garage', :field_name => 'DGARG1C'
      store 'attached_2car_garage', :field_name => 'GARAGE2C'
      store 'detached_2car_garage', :field_name => 'DGARG2C'
      store 'attached_3car_garage', :field_name => 'GARAGE3C'
      store 'detached_3car_garage', :field_name => 'DGARG3C'
      store 'lights_on_1_to_4_hours', :field_name => 'LGT1'
      store 'efficient_lights_on_1_to_4_hours', :field_name => 'LGT1EE'
      store 'lights_on_4_to_12_hours', :field_name => 'LGT4'
      store 'efficient_lights_on_4_to_12_hours', :field_name => 'LGT4EE'
      store 'lights_on_over_12_hours', :field_name => 'LGT12'
      store 'efficient_lights_on_over_12_hours', :field_name => 'LGT12EE'
      store 'outdoor_all_night_lights', :field_name => 'NOUTLGTNT'
      store 'outdoor_all_night_gas_lights', :field_name => 'NGASLIGHT'
    end

    # Rather than nullify the continuous variables that EIA identifies as LEGITIMATE SKIPS, we convert them to zero
    # This makes it easier to derive useful information like "how many rooms does the house have?"
    process 'Zero out what the EIA calls "LEGITIMATE SKIPS"' do
      %w{
        annual_energy_from_electricity_for_air_conditioners
        annual_energy_from_electricity_for_clothes_driers
        annual_energy_from_electricity_for_dishwashers
        annual_energy_from_electricity_for_freezers
        annual_energy_from_electricity_for_heating_space
        annual_energy_from_electricity_for_heating_water
        annual_energy_from_electricity_for_other_appliances
        annual_energy_from_electricity_for_refrigerators
        annual_energy_from_fuel_oil_for_appliances
        annual_energy_from_fuel_oil_for_heating_space
        annual_energy_from_fuel_oil_for_heating_water
        annual_energy_from_kerosene
        annual_energy_from_propane_for_appliances
        annual_energy_from_propane_for_heating_space
        annual_energy_from_propane_for_heating_water
        annual_energy_from_natural_gas_for_appliances
        annual_energy_from_natural_gas_for_heating_space
        annual_energy_from_natural_gas_for_heating_water
        annual_energy_from_wood
        lights_on_1_to_4_hours
        lights_on_over_12_hours
        efficient_lights_on_over_12_hours
        efficient_lights_on_1_to_4_hours
        lights_on_4_to_12_hours
        efficient_lights_on_4_to_12_hours
        outdoor_all_night_gas_lights
        outdoor_all_night_lights
        thermostat_programmability
        detached_1car_garage
        detached_2car_garage
        detached_3car_garage
        attached_1car_garage
        attached_2car_garage
        attached_3car_garage
        heated_garage
      }.each do |attr_name|
        max = maximum attr_name, :select => "CONVERT(#{attr_name}, UNSIGNED INTEGER)"
        # if the maximum value of a row is all 999's, then it's a LEGITIMATE SKIP and we should set it to zero
        if /^9+$/.match(max.to_i.to_s)
          update_all "#{attr_name} = 0", "#{attr_name} = #{max}"
        end
      end
    end

    process 'Convert units to metric after zeroing out LEGITIMATE SKIPS' do
      [
        [ 'floorspace', :square_feet, :square_metres ],
        [ 'annual_energy_from_fuel_oil_for_heating_space', :kbtus, :joules ],
        [ 'annual_energy_from_fuel_oil_for_heating_water', :kbtus, :joules ],
        [ 'annual_energy_from_fuel_oil_for_appliances', :kbtus, :joules ],
        [ 'annual_energy_from_natural_gas_for_heating_space', :kbtus, :joules ],
        [ 'annual_energy_from_natural_gas_for_heating_water', :kbtus, :joules ],
        [ 'annual_energy_from_natural_gas_for_appliances', :kbtus, :joules ],
        [ 'annual_energy_from_propane_for_heating_space', :kbtus, :joules ],
        [ 'annual_energy_from_propane_for_heating_water', :kbtus, :joules ],
        [ 'annual_energy_from_propane_for_appliances', :kbtus, :joules ],
        [ 'annual_energy_from_wood', :kbtus, :joules ],
        [ 'annual_energy_from_kerosene', :kbtus, :joules ],
        [ 'annual_energy_from_electricity_for_clothes_driers', :kbtus, :joules ],
        [ 'annual_energy_from_electricity_for_dishwashers', :kbtus, :joules ],
        [ 'annual_energy_from_electricity_for_freezers', :kbtus, :joules ],
        [ 'annual_energy_from_electricity_for_refrigerators', :kbtus, :joules ],
        [ 'annual_energy_from_electricity_for_air_conditioners', :kbtus, :joules ],
        [ 'annual_energy_from_electricity_for_heating_space', :kbtus, :joules ],
        [ 'annual_energy_from_electricity_for_heating_water', :kbtus, :joules ],
        [ 'annual_energy_from_electricity_for_other_appliances', :kbtus, :joules ],
      ].each do |attr_name, from_units, to_units|
        update_all "#{attr_name} = #{attr_name} * #{Conversions::Unit.exchange_rate from_units, to_units}"
      end
    end

    process 'Add a new field "rooms" that estimates how many rooms are in the house' do
      update_all 'rooms = total_rooms + bathrooms/2 + halfbaths/4 + heated_garage*(attached_1car_garage + detached_1car_garage + 2*(attached_2car_garage + detached_2car_garage) + 3*(attached_3car_garage + detached_3car_garage))'
    end

    process 'Add a new field "lighting_use" that estimates how many hours light bulbs are turned on in the house' do
      update_all 'lighting_use = 2*(lights_on_1_to_4_hours + efficient_lights_on_1_to_4_hours) + 8*(lights_on_4_to_12_hours + efficient_lights_on_4_to_12_hours) + 16*(lights_on_over_12_hours + efficient_lights_on_over_12_hours) + 12*(outdoor_all_night_lights + outdoor_all_night_gas_lights)'
    end

    process 'Add a new field "lighting_efficiency" that estimates what percentage of light bulbs in a house are energy-efficient' do
      update_all 'lighting_efficiency = (2*efficient_lights_on_1_to_4_hours + 8*efficient_lights_on_4_to_12_hours + 16*efficient_lights_on_over_12_hours) / lighting_use'
    end
  end
end

# T-100 Segment (All Carriers):  http://www.transtats.bts.gov/Fields.asp?Table_ID=293
class T100FlightSegment < ActiveRecord::Base
  set_primary_key :row_hash
  URL = 'http://www.transtats.bts.gov/DownLoad_Table.asp?Table_ID=293&Has_Group=3&Is_Zipped=0'
  FORM_DATA = %{
    UserTableName=T_100_Segment__All_Carriers&
    DBShortName=Air_Carriers&
    RawDataTable=T_T100_SEGMENT_ALL_CARRIER&
    sqlstr=+SELECT+DEPARTURES_SCHEDULED%2CDEPARTURES_PERFORMED%2CPAYLOAD%2CSEATS%2CPASSENGERS%2CFREIGHT%2CMAIL%2CDISTANCE%2CRAMP_TO_RAMP%2CAIR_TIME%2CUNIQUE_CARRIER%2CAIRLINE_ID%2CUNIQUE_CARRIER_NAME%2CUNIQUE_CARRIER_ENTITY%2CREGION%2CCARRIER%2CCARRIER_NAME%2CCARRIER_GROUP%2CCARRIER_GROUP_NEW%2CORIGIN%2CORIGIN_CITY_NAME%2CORIGIN_CITY_NUM%2CORIGIN_STATE_ABR%2CORIGIN_STATE_FIPS%2CORIGIN_STATE_NM%2CORIGIN_COUNTRY%2CORIGIN_COUNTRY_NAME%2CORIGIN_WAC%2CDEST%2CDEST_CITY_NAME%2CDEST_CITY_NUM%2CDEST_STATE_ABR%2CDEST_STATE_FIPS%2CDEST_STATE_NM%2CDEST_COUNTRY%2CDEST_COUNTRY_NAME%2CDEST_WAC%2CAIRCRAFT_GROUP%2CAIRCRAFT_TYPE%2CAIRCRAFT_CONFIG%2CYEAR%2CQUARTER%2CMONTH%2CDISTANCE_GROUP%2CCLASS%2CDATA_SOURCE+FROM++T_T100_SEGMENT_ALL_CARRIER+WHERE+Month+%3D__MONTH_NUMBER__+AND+YEAR%3D__YEAR__&
    varlist=DEPARTURES_SCHEDULED%2CDEPARTURES_PERFORMED%2CPAYLOAD%2CSEATS%2CPASSENGERS%2CFREIGHT%2CMAIL%2CDISTANCE%2CRAMP_TO_RAMP%2CAIR_TIME%2CUNIQUE_CARRIER%2CAIRLINE_ID%2CUNIQUE_CARRIER_NAME%2CUNIQUE_CARRIER_ENTITY%2CREGION%2CCARRIER%2CCARRIER_NAME%2CCARRIER_GROUP%2CCARRIER_GROUP_NEW%2CORIGIN%2CORIGIN_CITY_NAME%2CORIGIN_CITY_NUM%2CORIGIN_STATE_ABR%2CORIGIN_STATE_FIPS%2CORIGIN_STATE_NM%2CORIGIN_COUNTRY%2CORIGIN_COUNTRY_NAME%2CORIGIN_WAC%2CDEST%2CDEST_CITY_NAME%2CDEST_CITY_NUM%2CDEST_STATE_ABR%2CDEST_STATE_FIPS%2CDEST_STATE_NM%2CDEST_COUNTRY%2CDEST_COUNTRY_NAME%2CDEST_WAC%2CAIRCRAFT_GROUP%2CAIRCRAFT_TYPE%2CAIRCRAFT_CONFIG%2CYEAR%2CQUARTER%2CMONTH%2CDISTANCE_GROUP%2CCLASS%2CDATA_SOURCE&
    grouplist=&
    suml=&
    sumRegion=&
    filter1=title%3D&
    filter2=title%3D&
    geo=All%A0&
    time=__MONTH_NAME__&
    timename=Month&
    GEOGRAPHY=All&
    XYEAR=__YEAR__&
    FREQUENCY=__MONTH_NUMBER__&
    AllVars=All&
    VarName=DEPARTURES_SCHEDULED&
    VarDesc=DepScheduled&
    VarType=Num&
    VarName=DEPARTURES_PERFORMED&
    VarDesc=DepPerformed&
    VarType=Num&
    VarName=PAYLOAD&
    VarDesc=Payload&
    VarType=Num&
    VarName=SEATS&
    VarDesc=Seats&
    VarType=Num&
    VarName=PASSENGERS&
    VarDesc=Passengers&
    VarType=Num&
    VarName=FREIGHT&
    VarDesc=Freight&
    VarType=Num&
    VarName=MAIL&
    VarDesc=Mail&
    VarType=Num&
    VarName=DISTANCE&
    VarDesc=Distance&
    VarType=Num&
    VarName=RAMP_TO_RAMP&
    VarDesc=RampToRamp&
    VarType=Num&
    VarName=AIR_TIME&
    VarDesc=AirTime&
    VarType=Num&
    VarName=UNIQUE_CARRIER&
    VarDesc=UniqueCarrier&
    VarType=Char&
    VarName=AIRLINE_ID&
    VarDesc=AirlineID&
    VarType=Num&
    VarName=UNIQUE_CARRIER_NAME&
    VarDesc=UniqueCarrierName&
    VarType=Char&
    VarName=UNIQUE_CARRIER_ENTITY&
    VarDesc=UniqCarrierEntity&
    VarType=Char&
    VarName=REGION&
    VarDesc=CarrierRegion&
    VarType=Char&
    VarName=CARRIER&
    VarDesc=Carrier&
    VarType=Char&
    VarName=CARRIER_NAME&
    VarDesc=CarrierName&
    VarType=Char&
    VarName=CARRIER_GROUP&
    VarDesc=CarrierGroup&
    VarType=Num&
    VarName=CARRIER_GROUP_NEW&
    VarDesc=CarrierGroupNew&
    VarType=Num&
    VarName=ORIGIN&
    VarDesc=Origin&
    VarType=Char&
    VarName=ORIGIN_CITY_NAME&
    VarDesc=OriginCityName&
    VarType=Char&
    VarName=ORIGIN_CITY_NUM&
    VarDesc=OriginCityNum&
    VarType=Num&
    VarName=ORIGIN_STATE_ABR&
    VarDesc=OriginState&
    VarType=Char&
    VarName=ORIGIN_STATE_FIPS&
    VarDesc=OriginStateFips&
    VarType=Char&
    VarName=ORIGIN_STATE_NM&
    VarDesc=OriginStateName&
    VarType=Char&
    VarName=ORIGIN_COUNTRY&
    VarDesc=OriginCountry&
    VarType=Char&
    VarName=ORIGIN_COUNTRY_NAME&
    VarDesc=OriginCountryName&
    VarType=Char&
    VarName=ORIGIN_WAC&
    VarDesc=OriginWac&
    VarType=Num&
    VarName=DEST&
    VarDesc=Dest&
    VarType=Char&
    VarName=DEST_CITY_NAME&
    VarDesc=DestCityName&
    VarType=Char&
    VarName=DEST_CITY_NUM&
    VarDesc=DestCityNum&
    VarType=Num&
    VarName=DEST_STATE_ABR&
    VarDesc=DestState&
    VarType=Char&
    VarName=DEST_STATE_FIPS&
    VarDesc=DestStateFips&
    VarType=Char&
    VarName=DEST_STATE_NM&
    VarDesc=DestStateName&
    VarType=Char&
    VarName=DEST_COUNTRY&
    VarDesc=DestCountry&
    VarType=Char&
    VarName=DEST_COUNTRY_NAME&
    VarDesc=DestCountryName&
    VarType=Char&
    VarName=DEST_WAC&
    VarDesc=DestWac&
    VarType=Num&
    VarName=AIRCRAFT_GROUP&
    VarDesc=AircraftGroup&
    VarType=Num&
    VarName=AIRCRAFT_TYPE&
    VarDesc=AircraftType&
    VarType=Char&
    VarName=AIRCRAFT_CONFIG&
    VarDesc=AircraftConfig&
    VarType=Num&
    VarName=YEAR&
    VarDesc=Year&
    VarType=Num&
    VarName=QUARTER&
    VarDesc=Quarter&
    VarType=Num&
    VarName=MONTH&
    VarDesc=Month&
    VarType=Num&
    VarName=DISTANCE_GROUP&
    VarDesc=DistanceGroup&
    VarType=Num&
    VarName=CLASS&
    VarDesc=Class&
    VarType=Char&
    VarName=DATA_SOURCE&
    VarDesc=DataSource&
    VarType=Char
  }.gsub /[\s]+/,''

  data_miner do
    months = Hash.new
    # (2008..2009).each do |year|
    (2008..2008).each do |year|
      # (1..12).each do |month|
      (1..1).each do |month|
        time = Time.gm year, month
        form_data = FORM_DATA.dup
        form_data.gsub! '__YEAR__', time.year.to_s
        form_data.gsub! '__MONTH_NUMBER__', time.month.to_s
        form_data.gsub! '__MONTH_NAME__', time.strftime('%B')
        months[time] = form_data
      end
    end
    months.each do |month, form_data|
      import "T100 data from #{month.strftime('%B %Y')}",
           :url => URL,
           :form_data => form_data,
           :compression => :zip,
           :glob => '/*.csv' do
        key 'row_hash'
        store 'departures_scheduled', :field_name => 'DEPARTURES_SCHEDULED'
        store 'departures_performed', :field_name => 'DEPARTURES_PERFORMED'
        store 'payload', :field_name => 'PAYLOAD', :from_units => :pounds, :to_units => :kilograms
        store 'seats', :field_name => 'SEATS'
        store 'passengers', :field_name => 'PASSENGERS'
        store 'freight', :field_name => 'FREIGHT', :from_units => :pounds, :to_units => :kilograms
        store 'mail', :field_name => 'MAIL', :from_units => :pounds, :to_units => :kilograms
        store 'distance', :field_name => 'DISTANCE', :from_units => :miles, :to_units => :kilometres
        store 'ramp_to_ramp', :field_name => 'RAMP_TO_RAMP'
        store 'air_time', :field_name => 'AIR_TIME'
        store 'unique_carrier', :field_name => 'UNIQUE_CARRIER'
        store 'dot_airline_id', :field_name => 'AIRLINE_ID'
        store 'unique_carrier_name', :field_name => 'UNIQUE_CARRIER_NAME'
        store 'unique_carrier_entity', :field_name => 'UNIQUE_CARRIER_ENTITY'
        store 'region', :field_name => 'REGION'
        store 'carrier', :field_name => 'CARRIER'
        store 'carrier_name', :field_name => 'CARRIER_NAME'
        store 'carrier_group', :field_name => 'CARRIER_GROUP'
        store 'carrier_group_new', :field_name => 'CARRIER_GROUP_NEW'
        store 'origin_airport_iata', :field_name => 'ORIGIN'
        store 'origin_city_name', :field_name => 'ORIGIN_CITY_NAME'
        store 'origin_city_num', :field_name => 'ORIGIN_CITY_NUM'
        store 'origin_state_abr', :field_name => 'ORIGIN_STATE_ABR'
        store 'origin_state_fips', :field_name => 'ORIGIN_STATE_FIPS'
        store 'origin_state_nm', :field_name => 'ORIGIN_STATE_NM'
        store 'origin_country_iso_3166', :field_name => 'ORIGIN_COUNTRY'
        store 'origin_country_name', :field_name => 'ORIGIN_COUNTRY_NAME'
        store 'origin_wac', :field_name => 'ORIGIN_WAC'
        store 'dest_airport_iata', :field_name => 'DEST'
        store 'dest_city_name', :field_name => 'DEST_CITY_NAME'
        store 'dest_city_num', :field_name => 'DEST_CITY_NUM'
        store 'dest_state_abr', :field_name => 'DEST_STATE_ABR'
        store 'dest_state_fips', :field_name => 'DEST_STATE_FIPS'
        store 'dest_state_nm', :field_name => 'DEST_STATE_NM'
        store 'dest_country_iso_3166', :field_name => 'DEST_COUNTRY'
        store 'dest_country_name', :field_name => 'DEST_COUNTRY_NAME'
        store 'dest_wac', :field_name => 'DEST_WAC'
        store 'bts_aircraft_group', :field_name => 'AIRCRAFT_GROUP'
        store 'bts_aircraft_type', :field_name => 'AIRCRAFT_TYPE'
        store 'bts_aircraft_config', :field_name => 'AIRCRAFT_CONFIG'
        store 'year', :field_name => 'YEAR'
        store 'quarter', :field_name => 'QUARTER'
        store 'month', :field_name => 'MONTH'
        store 'bts_distance_group', :field_name => 'DISTANCE_GROUP'
        store 'bts_service_class', :field_name => 'CLASS'
        store 'data_source', :field_name => 'DATA_SOURCE'
      end
    end

    process 'Derive freight share as a fraction of payload' do
      update_all 'freight_share = (freight + mail) / payload', 'payload > 0'
    end

    process 'Derive load factor, which is passengers divided by the total seats available' do
      update_all 'load_factor = passengers / seats', 'passengers <= seats'
    end

    process 'Derive average seats per departure' do
      update_all 'seats_per_departure = seats / departures_performed', 'departures_performed > 0'
    end
  end
end

# note that this depends on stuff in Aircraft
class AircraftDeux < ActiveRecord::Base
  set_primary_key :icao_code

  # defined on the class because we defined the errata with a shorthand
  class << self
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
              :errata => { :url => 'http://spreadsheets.google.com/pub?key=tObVAGyqOkCBtGid0tJUZrw' },
              :row_xpath => '//table/tr[2]/td/table/tr',
              :column_xpath => 'td') do
        key 'icao_code', :field_name => 'Designator'
        store 'bts_name', :matcher => Aircraft::BtsNameMatcher.new
        store 'bts_aircraft_type_code', :matcher => Aircraft::BtsAircraftTypeCodeMatcher.new
        store 'manufacturer_name', :field_name => 'Manufacturer'
        store 'name', :field_name => 'Model'
      end
    end
  end
end

class AutomobileMakeFleetYear < ActiveRecord::Base
  set_primary_key :name

  col :name
  col :make_name
  col :fleet
  col :year, :type => :integer
  col :fuel_efficiency, :type => :float
  col :fuel_efficiency_units
  col :volume, :type => :integer
  col :make_year_name
  col :created_at, :type => :datetime
  col :updated_at, :type => :datetime

  data_miner do
    process :auto_upgrade!

    process "finish if i tell you to" do
      raise DataMiner::Finish if $force_finish
    end

    process "skip if i tell you to" do
      raise DataMiner::Skip if $force_skip
    end

    # CAFE data privately emailed to Andy from Terry Anderson at the DOT/NHTSA
    import :url => 'http://static.brighterplanet.com/science/data/transport/automobiles/make_fleet_years/make_fleet_years.csv',
           :errata => { :url => 'http://static.brighterplanet.com/science/data/transport/automobiles/make_fleet_years/errata.csv' },
           :select => lambda { |row| row['volume'].to_i > 0 } do
      key   'name', :synthesize => lambda { |row| [ row['manufacturer_name'], row['fleet'][2,2], row['year_content'] ].join ' ' }
      store 'make_name', :field_name => 'manufacturer_name'
      store 'year', :field_name => 'year_content'
      store 'fleet', :chars => 2..3 # zero-based
      store 'fuel_efficiency', :from_units => :miles_per_gallon, :to_units => :kilometres_per_litre
      store 'volume'
    end
  end
end

class CensusDivisionTrois < ActiveRecord::Base
  set_primary_key :number_code

  col :number_code
  col :name
  col :census_region_name
  col :census_region_number, :type => :integer
  add_index 'census_region_name', :name => 'homefry'
  add_index ['number_code', 'name', 'census_region_name', 'census_region_number']

  data_miner do
    process :auto_upgrade!
  end
end

class CensusDivisionFour < ActiveRecord::Base
col :number_code
col :name
col :census_region_name
col :census_region_number, :type => :integer
add_index 'census_region_name', :name => 'homefry'

  data_miner do
    process :auto_upgrade!
  end
end

# todo: have somebody properly organize these
class TestOldSyntax < Test::Unit::TestCase
  if ENV['WIP']
    context 'with nullify option' do
      should 'treat blank fields as null values' do
        Aircraft.delete_all
        Aircraft.data_miner_runs.delete_all
        Aircraft.run_data_miner!
        assert_greater_than 0, Aircraft.count
        assert_false Aircraft.where(:brighter_planet_aircraft_class_code => nil).empty?
      end
    end
  end

  if ENV['ALL'] == 'true'
    should 'directly create a table for the model' do
      if AutomobileMakeFleetYear.table_exists?
        ActiveRecord::Base.connection.execute 'DROP TABLE automobile_make_fleet_years;'
      end
      AutomobileMakeFleetYear.auto_upgrade!
      assert AutomobileMakeFleetYear.table_exists?
    end
  end

  if ENV['ALL'] == 'true' or ENV['FAST'] == 'true'
    should 'append to an existing config' do
      AutomobileFuelType.class_eval do
        data_miner :append => true do
          import 'example1', :url => 'http://example1.com' do
            key 'code'
            store 'name'
          end
        end
        data_miner :append => true do
          import 'example2', :url => 'http://example2.com' do
            key 'code'
            store 'name'
          end
        end
      end
      assert_equal 'http://example1.com', AutomobileFuelType.data_miner_config.steps[-2].table.url
      assert_equal 'http://example2.com', AutomobileFuelType.data_miner_config.steps[-1].table.url
    end

    should 'override an existing data_miner configuration' do
      AutomobileFuelType.class_eval do
        data_miner do
          import 'example', :url => 'http://example.com' do
            key 'code'
            store 'name'
          end
        end
      end
      assert_kind_of DataMiner::Import, AutomobileFuelType.data_miner_config.steps.first
      assert_equal 'http://example.com', AutomobileFuelType.data_miner_config.steps.first.table.url
    end
    should "stop and finish if it gets a DataMiner::Finish" do
      AutomobileMakeFleetYear.delete_all
      AutomobileMakeFleetYear.data_miner_runs.delete_all
      $force_finish = true
      AutomobileMakeFleetYear.run_data_miner!
      assert_equal 0, AutomobileMakeFleetYear.count
      assert (AutomobileMakeFleetYear.data_miner_runs.count > 0)
      assert AutomobileMakeFleetYear.data_miner_runs.all? { |run| run.finished? and not run.skipped and not run.killed? }
      $force_finish = false
      AutomobileMakeFleetYear.run_data_miner!
      assert AutomobileMakeFleetYear.exists?(:name => 'Alfa Romeo IP 1978')
    end

    should "stop and register skipped if it gets a DataMiner::Skip" do
      AutomobileMakeFleetYear.delete_all
      AutomobileMakeFleetYear.data_miner_runs.delete_all
      $force_skip = true
      AutomobileMakeFleetYear.run_data_miner!
      assert_equal 0, AutomobileMakeFleetYear.count
      assert (AutomobileMakeFleetYear.data_miner_runs.count > 0)
      assert AutomobileMakeFleetYear.data_miner_runs.all? { |run| run.skipped? and not run.finished? and not run.killed? }
      $force_skip = false
      AutomobileMakeFleetYear.run_data_miner!
      assert AutomobileMakeFleetYear.exists?(:name => 'Alfa Romeo IP 1978')
    end

    should "allow specifying dictionaries explicitly" do
      CensusDivisionDeux.run_data_miner!
      assert_equal 'South Region', CensusDivisionDeux.find(5).census_region_name
    end

    should "be able to key on things other than the primary key" do
      Aircraft.run_data_miner!
      assert_equal 'SP', Aircraft.find('DHC6').brighter_planet_aircraft_class_code
    end

    should "be able to synthesize rows without using a full parser class" do
      AutomobileMakeFleetYear.run_data_miner!
      assert AutomobileMakeFleetYear.exists?(:name => 'Alfa Romeo IP 1978')
    end

    should "keep a call stack so that you can call run_data_miner! on a child" do
      CrosscallingCensusDivision.run_data_miner!
      assert CrosscallingCensusDivision.exists? :name => 'Mountain Division', :number => 8, :census_region_number => 4, :census_region_name => 'West Region'
      assert CrosscallingCensusRegion.exists? :name => 'West Region', :number => 4
    end

    should "keep a call stack so that you can call run_data_miner! on a parent" do
      CrosscallingCensusRegion.run_data_miner!
      assert CrosscallingCensusDivision.exists? :name => 'Mountain Division', :number => 8, :census_region_number => 4, :census_region_name => 'West Region'
      assert CrosscallingCensusRegion.exists? :name => 'West Region', :number => 4
    end

    should "import airports" do
      Airport.run_data_miner!
      assert Airport.count > 0
    end

    should "pull in census divisions using a data.brighterplanet.com dictionary" do
      CensusDivision.run_data_miner!
      assert CensusDivision.count > 0
    end

    should "have a way to queue up runs that works with delated_job's send_later" do
      assert AutomobileVariant.respond_to?(:run_data_miner!)
    end

    should "be idempotent" do
      Country.data_miner_config.run
      a = Country.count
      Country.data_miner_config.run
      b = Country.count
      assert_equal a, b

      CensusRegion.data_miner_config.run
      a = CensusRegion.count
      CensusRegion.data_miner_config.run
      b = CensusRegion.count
      assert_equal a, b
    end

    should "hash things" do
      AutomobileVariant.data_miner_config.steps[0].run
      assert AutomobileVariant.first.row_hash.present?
    end

    should "process a callback block instead of a method" do
      AutomobileVariant.delete_all
      AutomobileVariant.data_miner_config.steps[0].run
      assert !AutomobileVariant.first.fuel_efficiency_city.present?
      AutomobileVariant.data_miner_config.steps.last.run
      assert AutomobileVariant.first.fuel_efficiency_city.present?
    end

    should "keep a log when it does a run" do
      approx_started_at = Time.now
      DataMiner.run :resource_names => %w{ Country }
      approx_terminated_at = Time.now
      last_run = DataMiner::Run.first(:conditions => { :resource_name => 'Country' }, :order => 'id DESC')
      assert (last_run.started_at - approx_started_at).abs < 5 # seconds
      assert (last_run.terminated_at - approx_terminated_at).abs < 5 # seconds
    end

    should "request a re-import from scratch" do
      c = Country.new
      c.iso_3166 = 'JUNK'
      c.save!
      assert Country.exists?(:iso_3166 => 'JUNK')
      DataMiner.run :resource_names => %w{ Country }, :from_scratch => true
      assert !Country.exists?(:iso_3166 => 'JUNK')
    end

    should "know what runs were on a resource" do
      DataMiner.run :resource_names => %w{ Country }
      DataMiner.run :resource_names => %w{ Country }
      assert Country.data_miner_runs.count > 0
    end
  end

  if ENV['ALL'] == 'true' or ENV['SLOW'] == 'true'
    should "allow errata to be specified with a shorthand, assuming the responder is the resource class itself" do
      AircraftDeux.run_data_miner!
      assert AircraftDeux.exists? :icao_code => 'DC91', :bts_aircraft_type_code => '630'
    end

    should "mine aircraft" do
      Aircraft.run_data_miner!
      assert Aircraft.exists? :icao_code => 'DC91', :bts_aircraft_type_code => '630'
    end

    should "mine automobile variants" do
      AutomobileVariant.run_data_miner!
      assert AutomobileVariant.count('make_name LIKE "%tesla"') > 0
    end

    should "mine T100 flight segments" do
      T100FlightSegment.run_data_miner!
      assert T100FlightSegment.count('dest_country_name LIKE "%United States"') > 0
    end

    should "mine residence survey responses" do
      ResidentialEnergyConsumptionSurveyResponse.run_data_miner!
      assert ResidentialEnergyConsumptionSurveyResponse.find(6).residence_class.start_with?('Single-family detached house')
    end
  end
end
