require 'test_helper'

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

class AutomobileVariant < ActiveRecord::Base
  set_primary_key :row_hash

  module FuelEconomyGuide
    TRANSMISSIONS = {
      'A' => 'automatic', 
      'M' => 'manual', 
      'L' => 'automatic',     # Lockup/automatic
      'S' => 'semiautomatic', # Semiautomatic
      'C' => 'manual' # TODO verify for VW Syncro
    }

    ENGINE_TYPES = {
      '(GUZZLER)' => nil, # "gas guzzler"
      '(POLICE)' => nil, # police automobile_variant
      '(MPFI)' => 'injection',
      '(MPI*)' => 'injection',
      '(SPFI)' => 'injection',
      '(FFS)' => 'injection',
      '(TURBO)' => 'turbo',
      '(TRBO)' => 'turbo',
      '(TC*)' => 'turbo',
      '(FFS,TRBO)' => %w(injection turbo),
      '(S-CHARGE)' => 'supercharger',
      '(SC*)' => 'supercharger',
      '(DIESEL)' => nil, # diesel
      '(DSL)' => nil, # diesel
      '(ROTARY)' => nil, # rotary
      '(VARIABLE)' => nil, # variable displacement
      '(NO-CAT)' => nil, # no catalytic converter
      '(OHC)' => nil, # overhead camshaft
      '(OHV)' => nil, # overhead valves
      '(16-VALVE)' => nil, # 16V
      '(305)' => nil, # 305 cubic inch displacement
      '(307)' => nil, # 307 cubic inch displacement
      '(M-ENG)' => nil,
      '(W-ENG)' => nil,
      '(GM-BUICK)' => nil,
      '(GM-CHEV)' => nil,
      '(GM-OLDS)' => nil,
      '(GM-PONT)' => nil,
    }

    class ParserB
      attr_accessor :year
      def initialize(options = {})
        @year = options[:year]
      end

      def apply(row)
        row.merge!({
          'make'           => row['carline_mfr_name'], # make it line up with the errata
          'model'          => row['carline_name'],     # ditto
          'transmission'   => TRANSMISSIONS[row['model_trans'][0, 1]],
          'speeds'         => (row['model_trans'][1, 1] == 'V') ? 'variable' : row['model_trans'][1, 1],
          'turbo'          => [ENGINE_TYPES[row['engine_desc1']], ENGINE_TYPES[row['engine_desc2']]].flatten.include?('turbo'),
          'supercharger'   => [ENGINE_TYPES[row['engine_desc1']], ENGINE_TYPES[row['engine_desc2']]].flatten.include?('supercharger'),
          'injection'      => [ENGINE_TYPES[row['engine_desc1']], ENGINE_TYPES[row['engine_desc2']]].flatten.include?('injection'),
          'displacement'   => _displacement(row['opt_disp']),
          'year'           => year
        })
        row
      end

      def _displacement(str)
        str = str.gsub(/[\(\)]/, '').strip
        if str =~ /^(.+)L$/
          $1.to_f
        elsif str =~ /^(.+)CC$/
          $1.to_f / 1000
        end
      end

      def add_hints!(bus)
        bus[:format] = :fixed_width
        bus[:cut] = '13-' if year == 1995
        bus[:schema_name] = :fuel_economy_guide_b
        bus[:select] = lambda { |row| row['supress_code'].blank? and row['state_code'] == 'F' }
        Slither.define :fuel_economy_guide_b do |d|
          d.rows do |row|
            row.trap { true } # there's only one section
            row.column 'active_year'      , 4,    :type => :integer  #   ACTIVE YEAR
            row.column 'state_code'       , 1,    :type => :string  #   STATE CODE:  F=49-STATE,C=CALIFORNIA
            row.column 'carline_clss'     , 2,    :type => :integer  #   CARLINE CLASS CODE
            row.column 'carline_mfr_code' , 3,    :type => :integer  #   CARLINE MANUFACTURER CODE
            row.column 'carline_name'     , 28,   :type => :string  #   CARLINE NAME
            row.column 'disp_cub_in'      , 4,    :type => :integer   #  DISP CUBIC INCHES
            row.column 'fuel_system'      , 2,    :type => :string   #  FUEL SYSTEM: 'FI' FOR FUEL INJECTION, 2-DIGIT INTEGER VALUE FOR #OF VENTURIES IF CARBURETOR SYSTEM.
            row.column 'model_trans'      , 6,    :type => :string   #  TRANSMISSION TYPE
            row.column 'no_cyc'           , 2,    :type => :integer   #  NUMBER OF ENGINE CYLINDERS
            row.column 'date_time'        , 12,   :type => :string  #   DATE AND TIME RECORD ENTERED -YYMMDDHHMMSS (YEAR, MONTH, DAY, HOUR, MINUTE, SECOND)
            row.column 'release_date'     , 6,    :type => :string   #  RELEASE DATE - YYMMDD (YEAR, MONTH, DAY)
            row.column 'vi_mfr_code'      , 3,    :type => :integer   #  VI MANUFACTURER CODE
            row.column 'carline_code'     , 5,    :type => :integer   #  CARLINE CODE
            row.column 'basic_eng_id'     , 5,    :type => :integer   #  BASIC ENGINE INDEX
            row.column 'carline_mfr_name' , 32,   :type => :string  #   CARLINE MANUFACTURER NAME
            row.column 'suppress_code'    , 1,    :type => :integer    # SUPPRESSION CODE (NO SUPPRESSED RECORD IF FOR PUBLIC ACCESS)
            row.column 'est_city_mpg'     , 3,    :type => :integer    # ESTIMATED (CITY) MILES PER GALLON - 90% OF UNADJUSTED VALUE
            row.spacer 2
            row.column 'highway_mpg'      , 3,    :type => :integer    # ESTIMATED (HWY) MILES PER GALLON - 78% OF UNADJUSTED VALUE
            row.spacer 2
            row.column 'combined_mpg'     , 3,    :type => :integer    # COMBINED MILES PER GALLON
            row.spacer 2
            row.column 'unadj_city_mpg'   , 3,    :type => :integer    # UNADJUSTED  CITY MILES PER GALLON
            row.spacer 2
            row.column 'unadj_hwy_mpg'    , 3,    :type => :integer    # UNADJUSTED HIGHWAY MILES PER GALLON
            row.spacer 2
            row.column 'unadj_comb_mpg'   , 3,    :type => :integer    # UNADJUSTED COMBINED MILES PER GALLON
            row.spacer 2
            row.column 'ave_anl_fuel'     , 6,    :type => :integer    # "$" in col 147, Annual Fuel Cost starting col 148 in I5
            row.column 'opt_disp'         , 8,    :type => :string    # OPTIONAL DISPLACEMENT
            row.column 'engine_desc1'     , 10,   :type => :string   #  ENGINE DESCRIPTION 1
            row.column 'engine_desc2'     , 10,   :type => :string   #  ENGINE DESCRIPTION 2
            row.column 'engine_desc3'     , 10,   :type => :string   #  ENGINE DESCRIPTION 3
            row.column 'body_type_2d'     , 10,   :type => :string   #  BODY TYPE 2 DOOR - IF THE BODY TYPE APPLIES IT WILL TAKE THE FORM '2DR-PPP/LL' WHERE PPP=PASSENGER INTERIOR VOLUME AND LL=LUGGAGE INTERIOR VOLUME.
            row.column 'body_type_4d'     , 10,   :type => :string   #  BODY TYPE 4 DOOR - IF THE BODY TYPE APPLIES IT WILL TAKE THE FORM '4DR-PPP/LL' WHERE PPP=PASSENGER INTERIOR VOLUME AND LL=LUGGAGE INTERIOR VOLUME.
            row.column 'body_type_hbk'    , 10,   :type => :string   #  BODY TYPE HBK    - IF THE BODY TYPE APPLIES IT WILL TAKE THE FORM 'HBK-PPP/LL' WHERE PPP=PASSENGER INTERIOR VOLUME AND LL=LUGGAGE INTERIOR VOLUME.
            row.column 'puerto_rico'      , 1,    :type => :string    # '*' IF FOR PUERTO RICO SALES ONLY
            row.column 'overdrive'        , 4,    :type => :string    # OVERDRIVE:  ' OD ' FOR OVERDRIVE, 'EOD ' FOR ELECTRICALLY OPERATED OVERDRIVE AND 'AEOD' FOR AUTOMATIC OVERDRIVE
            row.column 'drive_system'     , 3,    :type => :string    # FWD=FRONT WHEEL DRIVE, RWD=REAR,  4WD=4-WHEEL
            row.column 'filler'           , 1,    :type => :string    # NOT USED
            row.column 'fuel_type'        , 1,    :type => :string    # R=REGULAR(UNLEADED), P=PREMIUM,  D=DIESEL
            row.column 'trans_desc'       , 15,   :type => :string   #  TRANSMISSION DESCRIPTORS
          end
        end
      end
    end
    class ParserC
      attr_accessor :year
      def initialize(options = {})
        @year = options[:year]
      end

      def add_hints!(bus)
        # File will decide format based on filename
      end

      def apply(row)
        row.merge!({
          'make'           => row['Manufacturer'], # make it line up with the errata
          'model'          => row['carline name'], # ditto
          'drive'          => row['drv'] + 'WD',
          'transmission'   => TRANSMISSIONS[row['trans'][-3, 1]],
          'speeds'         => (row['trans'][-2, 1] == 'V') ? 'variable' : row['trans'][-2, 1],
          'turbo'          => row['T'] == 'T',
          'supercharger'   => row['S'] == 'S',
          'injection'      => true,
          'year'           => year
        })
        row
      end
    end
    class ParserD
      attr_accessor :year
      def initialize(options = {})
        @year = options[:year]
      end

      def add_hints!(bus)
        bus[:reject] = lambda { |row| row.values.first.blank? } if year == 2007
      end

      def apply(row)
        row.merge!({
          'make'           => row['MFR'],          # make it line up with the errata
          'model'          => row['CAR LINE'],     # ditto
          'drive'          => row['DRIVE SYS'] + 'WD',
          'transmission'   => TRANSMISSIONS[row['TRANS'][-3, 1]],
          'speeds'         => (row['TRANS'][-2, 1] == 'V') ? 'variable' : row['TRANS'][-2, 1],
          'turbo'          => row['TURBO'] == 'T',
          'supercharger'   => row['SPCHGR'] == 'S',
          'injection'      => true,
          'year'           => year
        })
        row
      end
    end
  end
  
  class Guru
    # the following matching methods are needed by the errata
    # per https://brighterplanet.sifterapp.com/projects/30/issues/750/comments

    def transmission_is_blank?(row)
      row['transmission'].blank?
    end

    def is_a_2007_gmc_or_chevrolet?(row)
      row['year'] == 2007 and %w(GMC CHEVROLET).include? row['MFR'].upcase
    end

    def is_a_porsche?(row)
      row['make'].upcase == 'PORSCHE'
    end

    def is_not_a_porsche?(row)
      !is_a_porsche? row
    end

    def is_a_mercedes_benz?(row)
      row['make'] =~ /MERCEDES/i
    end

    def is_a_lexus?(row)
      row['make'].upcase == 'LEXUS'
    end

    def is_a_bmw?(row)
      row['make'].upcase == 'BMW'
    end

    def is_a_ford?(row)
      row['make'].upcase == 'FORD'
    end

    def is_a_rolls_royce_and_model_contains_bentley?(row)
      is_a_rolls_royce?(row) and model_contains_bentley?(row)
    end

    def is_a_bentley?(row)
      row['make'].upcase == 'BENTLEY'
    end

    def is_a_rolls_royce?(row)
      row['make'] =~ /ROLLS/i
    end

    def is_a_turbo_brooklands?(row)
      row['model'] =~ /TURBO R\/RL BKLDS/i
    end

    def model_contains_maybach?(row)
      row['model'] =~ /MAYBACH/i
    end
    
    def model_contains_bentley?(row)
      row['model'] =~ /BENTLEY/i
    end
  end
  
  errata = Errata.new :url => 'http://static.brighterplanet.com/science/data/transport/automobiles/fuel_economy_guide/errata.csv',
                      :responder => AutomobileVariant::Guru.new
  
  data_miner do
    # 1985---1997
    (85..97).each do |yy|
      filename = (yy == 96) ? "#{yy}MFGUI.ASC" : "#{yy}MFGUI.DAT"
      import(:url => "http://www.fueleconomy.gov/FEG/epadata/#{yy}mfgui.zip",
             :filename => filename,
             :transform => { :class => FuelEconomyGuide::ParserB, :year => "19#{yy}".to_i },
             :errata => errata) do
        key 'row_hash'
        store 'make_name', :field_name => 'make'
        store 'model_name', :field_name => 'model'
        store 'year'
        store 'fuel_type_code', :field_name => 'fuel_type'
        store 'fuel_efficiency_highway', :static => nil, :units => :kilometres_per_litre # we'll convert these in a later step, just setting the stage
        store 'fuel_efficiency_city', :static => nil, :units => :kilometres_per_litre    # ditto
        store 'raw_fuel_efficiency_highway', :field_name => 'unadj_hwy_mpg', :from_units => :miles_per_gallon, :to_units => :kilometres_per_litre
        store 'raw_fuel_efficiency_city', :field_name => 'unadj_city_mpg', :from_units => :miles_per_gallon, :to_units => :kilometres_per_litre
        store 'cylinders', :field_name => 'no_cyc'
        store 'drive', :field_name => 'drive_system'
        store 'carline_mfr_code'
        store 'vi_mfr_code'
        store 'carline_code'
        store 'carline_class_code', :field_name => 'carline_clss'
        store 'transmission'
        store 'speeds'
        store 'turbo'
        store 'supercharger'
        store 'injection'
        store 'displacement'
      end
    end
    
    # 1998--2005
    {
      1998 => { :url => 'http://www.fueleconomy.gov/FEG/epadata/98guide6.zip', :filename => '98guide6.csv' },
      1999 => { :url => 'http://www.fueleconomy.gov/FEG/epadata/99guide.zip', :filename => '99guide6.csv' },
      2000 => { :url => 'http://www.fueleconomy.gov/FEG/epadata/00data.zip', :filename => 'G6080900.xls' },
      2001 => { :url => 'http://static.brighterplanet.com/science/data/transport/automobiles/fuel_economy_guide/01guide0918.csv' }, # parseexcel 0.5.2 can't read Excel 5.0 { :url => 'http://www.fueleconomy.gov/FEG/epadata/01data.zip', :filename => '01guide0918.xls' }
      2002 => { :url => 'http://www.fueleconomy.gov/FEG/epadata/02data.zip', :filename => 'guide_jan28.xls' },
      2003 => { :url => 'http://www.fueleconomy.gov/FEG/epadata/03data.zip', :filename => 'guide_2003_feb04-03b.csv' },
      2004 => { :url => 'http://www.fueleconomy.gov/FEG/epadata/04data.zip', :filename => 'gd04-Feb1804-RelDtFeb20.csv' },
      2005 => { :url => 'http://www.fueleconomy.gov/FEG/epadata/05data.zip', :filename => 'guide2005-2004oct15.csv' }
    }.sort { |a, b| a.first <=> b.first }.each do |year, options|
      import options.merge(:transform => { :class => FuelEconomyGuide::ParserC, :year => year },
                           :errata => errata) do
        key 'row_hash'
        store 'make_name', :field_name => 'make'
        store 'model_name', :field_name => 'model'
        store 'fuel_type_code', :field_name => 'fl'
        store 'fuel_efficiency_highway', :static => nil, :units => :kilometres_per_litre # we'll convert these in a later step, just setting the stage
        store 'fuel_efficiency_city', :static => nil, :units => :kilometres_per_litre    # ditto
        store 'raw_fuel_efficiency_highway', :field_name => 'uhwy', :from_units => :miles_per_gallon, :to_units => :kilometres_per_litre
        store 'raw_fuel_efficiency_city', :field_name => 'ucty', :from_units => :miles_per_gallon, :to_units => :kilometres_per_litre
        store 'cylinders', :field_name => 'cyl'
        store 'displacement', :field_name => 'displ'
        store 'carline_class_code', :field_name => 'cls' if year >= 2000
        store 'carline_class_name', :field_name => 'Class'
        store 'year'
        store 'transmission'
        store 'speeds'
        store 'turbo'
        store 'supercharger'
        store 'injection'
        store 'drive'
      end
    end
    
    # 2006--2010
    {
      2006 => { :url => 'http://www.fueleconomy.gov/FEG/epadata/06data.zip', :filename => '2006_FE_Guide_14-Nov-2005_download.csv' },
      2007 => { :url => 'http://www.fueleconomy.gov/FEG/epadata/07data.zip', :filename => '2007_FE_guide_ALL_no_sales_May_01_2007.xls' },
      2008 => { :url => 'http://www.fueleconomy.gov/FEG/epadata/08data.zip', :filename => '2008_FE_guide_ALL_rel_dates_-no sales-for DOE-5-1-08.csv' },
      2009 => { :url => 'http://www.fueleconomy.gov/FEG/epadata/09data.zip', :filename => '2009_FE_guide for DOE_ALL-rel dates-no-sales-8-28-08download.csv' },
      # 2010 => { :url => 'http://www.fueleconomy.gov/FEG/epadata/10data.zip', :filename => '2010FEguide-for DOE-rel dates before 10-16-09-no-sales10-8-09public.xls' }
    }.sort { |a, b| a.first <=> b.first }.each do |year, options|
      import options.merge(:transform => { :class => FuelEconomyGuide::ParserD, :year => year },
                           :errata => errata) do
        key 'row_hash'
        store 'make_name', :field_name => 'make'
        store 'model_name', :field_name => 'model'
        store 'fuel_type_code', :field_name => 'FUEL TYPE'
        store 'fuel_efficiency_highway', :static => nil, :units => :kilometres_per_litre # we'll convert these in a later step, just setting the stage
        store 'fuel_efficiency_city', :static => nil, :units => :kilometres_per_litre    # ditto
        store 'raw_fuel_efficiency_highway', :field_name => 'UNRND HWY (EPA)', :from_units => :miles_per_gallon, :to_units => :kilometres_per_litre
        store 'raw_fuel_efficiency_city', :field_name => 'UNRND CITY (EPA)', :from_units => :miles_per_gallon, :to_units => :kilometres_per_litre
        store 'cylinders', :field_name => 'NUMB CYL'
        store 'displacement', :field_name => 'DISPLACEMENT'
        store 'carline_class_code', :field_name => 'CLS'
        store 'carline_class_name', :field_name => 'CLASS'
        store 'year'
        store 'transmission'
        store 'speeds'
        store 'turbo'
        store 'supercharger'
        store 'injection'
        store 'drive'
      end
    end
    
    # associate :make, :key => :original_automobile_make_name, :foreign_key => :name
    # derive :automobile_model_id # creates models by name
    # associate :fuel_type, :key => :original_automobile_fuel_type_code, :foreign_key => :code
    
    process 'Set adjusted fuel economy' do
      update_all 'fuel_efficiency_city = 1 / ((0.003259 / 0.425143707) + (1.1805 / raw_fuel_efficiency_city))'
      update_all 'fuel_efficiency_highway = 1 / ((0.001376 / 0.425143707) + (1.3466 / raw_fuel_efficiency_highway))'
    end
  end
  
  def name
    extra = []
    extra << "V#{cylinders}" if cylinders
    extra << "#{displacement}L" if displacement
    extra << "turbo" if turbo
    extra << "FI" if injection
    extra << "#{speeds}spd" if speeds.present?
    extra << transmission if transmission.present?
    extra << "(#{fuel_type.name})" if fuel_type
    extra.join(' ')
  end
  
  def fuel_economy_description
    [ fuel_efficiency_city, fuel_efficiency_highway ].map { |f| f.kilometres_per_litre.to(:miles_per_gallon).round }.join('/')
  end
end

class Country < ActiveRecord::Base
  set_primary_key :iso_3166
  
  data_miner do
    import 'The official ISO country list', :url => 'http://www.iso.org/iso/list-en1-semic-3.txt', :skip => 2, :headers => false, :delimiter => ';' do
      key 'iso_3166', :field_number => 1
      store 'name', :field_number => 0
    end
    
    import 'A Princeton dataset with better capitalization', :url => 'http://www.cs.princeton.edu/introcs/data/iso3166.csv' do
      key 'iso_3166', :field_name => 'country code'
      store 'name', :field_name => 'country'
    end
  end
end

class Airport < ActiveRecord::Base
  set_primary_key :iata_code
  
  data_miner do
    import :url => 'http://openflights.svn.sourceforge.net/viewvc/openflights/openflights/data/airports.dat', :headers => false, :select => lambda { |row| row[4].present? } do
      key 'iata_code', :field_number => 4
      store 'name', :field_number => 1
      store 'city', :field_number => 2
      store 'country_name', :field_number => 3
      store 'latitude', :field_number => 6
      store 'longitude', :field_number => 7
    end
  end
end

class TappedAirport < ActiveRecord::Base
  set_primary_key :iata_code
  
  data_miner do
    tap "Brighter Planet's sanitized airports table", "http://carbon:neutral@data.brighterplanet.com:5001", :source_table_name => 'airports'
    # tap "Brighter Planet's sanitized airports table", "http://carbon:neutral@localhost:5000", :source_table_name => 'airports'
  end
end

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
      create_table :crosscalling_census_regions, :options => 'ENGINE=InnoDB default charset=utf8', :id => false, :force => true do |t|
        t.column :number, :integer
        t.column :name, :string
      end
      execute 'ALTER TABLE crosscalling_census_regions ADD PRIMARY KEY (number);'
      execute %{
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

require 'loose_tight_dictionary'
class Aircraft < ActiveRecord::Base
  set_primary_key :icao_code

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
              :encoding => 'US-ASCII',
              :errata => Errata.new(:url => 'http://spreadsheets.google.com/pub?key=tObVAGyqOkCBtGid0tJUZrw',
                                    :responder => Aircraft::Guru.new),
              :row_xpath => '//table/tr[2]/td/table/tr',
              :column_xpath => 'td') do
        key 'icao_code', :field_name => 'Designator'
        store 'bts_name', :matcher => Aircraft::BtsNameMatcher.new
        store 'bts_aircraft_type_code', :matcher => Aircraft::BtsAircraftTypeCodeMatcher.new
        store 'manufacturer_name', :field_name => 'Manufacturer'
        store 'name', :field_name => 'Model'
      end
      
      import 'Brighter Planet aircraft class codes',
             :url => 'http://static.brighterplanet.com/science/data/transport/air/bts_aircraft_type/bts_aircraft_types-brighter_planet_aircraft_classes.csv' do
        key   'bts_aircraft_type_code', :field_name => 'bts_aircraft_type'
        store 'brighter_planet_aircraft_class_code'
      end
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
              :errata => 'http://spreadsheets.google.com/pub?key=tObVAGyqOkCBtGid0tJUZrw',
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

  data_miner do
    schema :id => false do
      string "name"
      string   "make_name"
      string   "fleet"
      integer   "year"
      float    "fuel_efficiency"
      string "fuel_efficiency_units"
      integer  "volume"
      string  "make_year_name"
      datetime "created_at"
      datetime "updated_at"
      integer  'data_miner_touch_count'
      integer  'data_miner_last_run_id'
    end

    # CAFE data privately emailed to Andy from Terry Anderson at the DOT/NHTSA
    import :url => 'http://static.brighterplanet.com/science/data/transport/automobiles/make_fleet_years/make_fleet_years.csv',
           :errata => 'http://static.brighterplanet.com/science/data/transport/automobiles/make_fleet_years/errata.csv',
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
  data_miner do
    schema :options => 'ENGINE=InnoDB default charset=utf8' do
      string  'number_code'
      string   'name'
      string   'census_region_name'
      integer  'census_region_number'
      index    'census_region_name', :name => 'homefry'
    end
  end
end

class CensusDivisionFour < ActiveRecord::Base
  data_miner do
    schema do
      string  'number_code'
      string   'name'
      string   'census_region_name'
      integer  'census_region_number'
      index    'census_region_name', :name => 'homefry'
    end
  end
end

# todo: have somebody properly organize these
class DataMinerTest < Test::Unit::TestCase
  if ENV['ALL'] == 'true' or ENV['NEW'] == 'true'
  end
    
  if ENV['ALL'] == 'true' or ENV['FAST'] == 'true'
    should "eagerly enforce a schema" do
      ActiveRecord::Base.connection.create_table 'census_division_trois', :force => true, :options => 'ENGINE=InnoDB default charset=utf8' do |t|
        t.string   'name'
        # t.datetime 'updated_at'
        # t.datetime 'created_at'
        t.string   'census_region_name'
        # t.integer  'census_region_number'
        # t.integer 'data_miner_touch_count'
        # t.integer 'data_miner_last_run_id'
      end
      ActiveRecord::Base.connection.execute 'ALTER TABLE census_division_trois ADD INDEX (census_region_name)'
      CensusDivisionTrois.reset_column_information
      missing_columns = %w{ updated_at created_at census_region_number data_miner_last_run_id data_miner_touch_count }

      # sanity check
      missing_columns.each do |column|
        assert_equal false, CensusDivisionTrois.column_names.include?(column)
      end
      assert_equal false, ActiveRecord::Base.connection.indexes(CensusDivisionTrois.table_name).any? { |index| index.name == 'homefry' }
      
      3.times do
        CensusDivisionTrois.run_data_miner!
        missing_columns.each do |column|
          assert_equal true, CensusDivisionTrois.column_names.include?(column)
        end
        assert_equal true, ActiveRecord::Base.connection.indexes(CensusDivisionTrois.table_name).any? { |index| index.name == 'homefry' }
        assert_equal :string, CensusDivisionTrois.columns_hash[CensusDivisionTrois.primary_key].type
      end
    end
    
    should "let schemas work with default id primary keys" do
      ActiveRecord::Base.connection.create_table 'census_division_fours', :id => true, :force => true, :options => 'ENGINE=InnoDB default charset=utf8' do |t|
        t.string   'name'
        # t.datetime 'updated_at'
        # t.datetime 'created_at'
        t.string   'census_region_name'
        # t.integer  'census_region_number'
        # t.integer 'data_miner_touch_count'
        # t.integer 'data_miner_last_run_id'
      end
      ActiveRecord::Base.connection.execute 'ALTER TABLE census_division_fours ADD INDEX (census_region_name)'
      CensusDivisionFour.reset_column_information
      missing_columns = %w{ updated_at created_at census_region_number data_miner_last_run_id data_miner_touch_count }
    
      # sanity check
      missing_columns.each do |column|
        assert_equal false, CensusDivisionFour.column_names.include?(column)
      end
      assert_equal false, ActiveRecord::Base.connection.indexes(CensusDivisionFour.table_name).any? { |index| index.name == 'homefry' }
      
      3.times do
        CensusDivisionFour.run_data_miner!
        missing_columns.each do |column|
          assert_equal true, CensusDivisionFour.column_names.include?(column)
        end
        assert_equal true, ActiveRecord::Base.connection.indexes(CensusDivisionFour.table_name).any? { |index| index.name == 'homefry' }
        assert_equal :integer, CensusDivisionFour.columns_hash[CensusDivisionFour.primary_key].type
      end
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
    
    should "tap airports" do
      TappedAirport.run_data_miner!
      assert TappedAirport.count > 0
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
      AutomobileVariant.data_miner_config.steps[0].run(nil)
      assert AutomobileVariant.first.row_hash.present?
    end
  
    should "process a callback block instead of a method" do
      AutomobileVariant.delete_all
      AutomobileVariant.data_miner_config.steps[0].run(nil)
      assert !AutomobileVariant.first.fuel_efficiency_city.present?
      AutomobileVariant.data_miner_config.steps.last.run(nil)
      assert AutomobileVariant.first.fuel_efficiency_city.present?
    end
  
    should "keep a log when it does a run" do
      approx_started_at = Time.now
      DataMiner.run :resource_names => %w{ Country }
      approx_ended_at = Time.now
      last_run = DataMiner::Run.first(:conditions => { :resource_name => 'Country' }, :order => 'id DESC')
      assert (last_run.started_at - approx_started_at).abs < 5 # seconds
      assert (last_run.ended_at - approx_ended_at).abs < 5 # seconds
    end
  
    should "request a re-import from scratch" do
      c = Country.new
      c.iso_3166 = 'JUNK'
      c.save!
      assert Country.exists?(:iso_3166 => 'JUNK')
      DataMiner.run :resource_names => %w{ Country }, :from_scratch => true
      assert !Country.exists?(:iso_3166 => 'JUNK')
    end
  
    should "track how many times a row was touched" do
      DataMiner.run :resource_names => %w{ Country }, :from_scratch => true
      assert_equal 1, Country.first.data_miner_touch_count
      DataMiner.run :resource_names => %w{ Country }
      assert_equal 1, Country.first.data_miner_touch_count
    end
  
    should "keep track of what the last import run that touched a row was" do
      DataMiner.run :resource_names => %w{ Country }, :from_scratch => true
      a = DataMiner::Run.last
      assert_equal a, Country.first.data_miner_last_run
      DataMiner.run :resource_names => %w{ Country }
      b = DataMiner::Run.last
      assert a != b
      assert_equal a, Country.first.data_miner_last_run
    end
  
    should "be able to get how many rows affected by a run" do
      DataMiner.run :resource_names => %w{ Country }, :from_scratch => true
      assert_equal Country.first.data_miner_last_run.resource_records_last_touched_by_me.count, Country.count
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
      assert ResidentialEnergyConsumptionSurveyResponse.find(6).residence_class.starts_with?('Single-family detached house')
    end
  end
end
