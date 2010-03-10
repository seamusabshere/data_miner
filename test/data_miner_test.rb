require 'test_helper'

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

class AutomobileMakeYear < ActiveRecord::Base
  set_primary_key :row_hash
  
  belongs_to :make, :class_name => 'AutomobileMake', :foreign_key => 'automobile_make_id'
  belongs_to :model_year, :class_name => 'AutomobileModelYear', :foreign_key => 'automobile_model_year_id'
  has_many :fleet_years, :class_name => 'AutomobileMakeFleetYear'
  
  data_miner do
    process :derive_from_make_fleet_years
    process :derive_association_to_make_fleet_years
    process :derive_fuel_efficiency
    process :derive_volume
  end
  
  # validates_numericality_of :fuel_efficiency, :greater_than => 0, :allow_nil => true
  
  class << self
    def derive_from_make_fleet_years
      AutomobileMakeFleetYear.find_in_batches do |batch|
        batch.each do |record|
          #puts "   * Considering AMFY #{record.inspect}"
          if record.make and record.model_year
            find_or_create_by_automobile_make_id_and_automobile_model_year_id record.make.id, record.model_year.id
          end
        end
      end
    end
    
    def derive_association_to_make_fleet_years
      AutomobileMakeFleetYear.find_in_batches do |batch|
        batch.each do |record|
          if record.make and record.model_year
            record.make_year = find_by_automobile_make_id_and_automobile_model_year_id record.make.id, record.model_year.id
            record.save! if record.changed?
          end
        end
      end
    end

    def derive_fuel_efficiency
      AutomobileMakeFleetYear.find_in_batches do |batch|
        batch.each do |record|
          if record.make and record.model_year
            make_year = find_by_automobile_make_id_and_automobile_model_year_id record.make.id, record.model_year.id
            # make_year.fuel_efficiency = make_year.fleet_years.weighted_average :fuel_efficiency, :by => :volume
            make_year.save!
          end
        end
      end
    end
    
    def derive_volume
      find_in_batches do |batch|
        batch.each do |record|
          record.volume = record.fleet_years.collect(&:volume).sum
          record.save!
        end
      end
    end
  end
end

class AutomobileMakeFleetYear < ActiveRecord::Base
  set_primary_key :row_hash
  belongs_to :make, :class_name => 'AutomobileMake', :foreign_key => 'automobile_make_id'
  belongs_to :model_year, :class_name => 'AutomobileModelYear', :foreign_key => 'automobile_model_year_id'
  belongs_to :make_year, :class_name => 'AutomobileMakeYear', :foreign_key => 'automobile_make_year_id'

  data_miner do
    # CAFE data privately emailed to Andy from Terry Anderson at the DOT/NHTSA
    import :url => 'http://static.brighterplanet.com/science/data/transport/automobiles/make_fleet_years/make_fleet_years.csv',
           :errata => 'http://static.brighterplanet.com/science/data/transport/automobiles/make_fleet_years/errata.csv',
           :select => lambda { |row| row['volume'].to_i > 0 } do |attr|
      attr.store 'make_name', :field_name => 'manufacturer_name' # prefix
      attr.store 'year', :field_name => 'year_content'
      attr.store 'fleet', :chars => 2..3
      attr.store 'fuel_efficiency', :from_units => :miles_per_gallon, :to_units => :kilometres_per_litre
      attr.store 'volume'
    end
  end
end

class AutomobileModelYear < ActiveRecord::Base
  set_primary_key :year
  
  has_many :make_years, :class_name => 'AutomobileMakeYear'
  has_many :variants, :class_name => 'AutomobileVariant'
  
  data_miner do
    unique_index 'year'
    
    # await :other_class => AutomobileMakeYear do |deferred|
    #   # deferred.derive :fuel_efficiency, :weighting_association => :make_years, :weighting_column => :volume
    # end
  end
end

class AutomobileFuelType < ActiveRecord::Base
  set_primary_key :code
  
  data_miner do
    unique_index 'code'
    
    import(:url => 'http://www.fueleconomy.gov/FEG/epadata/00data.zip',
                :filename => 'Gd6-dsc.txt',
                :format => :fixed_width,
                :crop => 21..26, # inclusive
                :cut => '2-',
                :select => lambda { |row| /\A[A-Z]/.match row[:code] },
                :schema => [[ 'code',   2, { :type => :string }  ],
                            [ 'spacer', 2 ],
                            [ 'name',   52, { :type => :string } ]]) do |attr|
      attr.store 'name'
    end

    import :url => 'http://static.brighterplanet.com/science/data/transport/automobiles/models_export/automobile_fuel_type.csv' do |attr|
      attr.store 'name'
      attr.store 'annual_distance'
      attr.store 'emission_factor'
    end

    # pull electricity emission factor from residential electricity
    import(:url => 'http://spreadsheets.google.com/pub?key=rukxnmuhhsOsrztTrUaFCXQ',
                :select => lambda { |row| row['code'] == 'El' }) do |attr|
      attr.store 'name'
      attr.store 'emission_factor'
    end
    
    # still need distance estimate for electric cars
  end
  
  CODES = {
    :electricity => 'El',
    :diesel => 'D'
  }
end

class AutomobileModel < ActiveRecord::Base
  set_primary_key :row_hash
  
  has_many :variants, :class_name => 'AutomobileVariant'
  belongs_to :make, :class_name => 'AutomobileMake', :foreign_key => 'automobile_make_id'
  
  data_miner do
    # derived from FEG automobile variants
  end
end

class AutomobileMake < ActiveRecord::Base
  set_primary_key :name

  has_many :make_years, :class_name => 'AutomobileMakeYear'
  has_many :models, :class_name => 'AutomobileModel'
  has_many :fleet_years, :class_name => 'AutomobileMakeFleetYear'
  has_many :variants, :class_name => 'AutomobileVariant'

  data_miner do
    unique_index 'name'
    
    import :url => 'http://static.brighterplanet.com/science/data/transport/automobiles/makes/make_importance.csv' do |attr|
      attr.store 'major'
    end
    # await :other_class => AutomobileMakeYear do |deferred|
    #   deferred.derive :fuel_efficiency, :weighting_association => :make_years, :weighting_column => 'volume'
    # end
  end
end

class AutomobileVariant < ActiveRecord::Base
  set_primary_key :row_hash
  
  belongs_to :make, :class_name => 'AutomobileMake', :foreign_key => 'automobile_make_id'
  belongs_to :model, :class_name => 'AutomobileModel', :foreign_key => 'automobile_model_id'
  belongs_to :model_year, :class_name => 'AutomobileModelYear', :foreign_key => 'automobile_model_year_id'
  belongs_to :fuel_type, :class_name => 'AutomobileFuelType', :foreign_key => 'automobile_fuel_type_id'

  data_miner do
    # 1985---1997
    (85..97).each do |yy|
      filename = (yy == 96) ? "#{yy}MFGUI.ASC" : "#{yy}MFGUI.DAT"
      import(:url => "http://www.fueleconomy.gov/FEG/epadata/#{yy}mfgui.zip",
                  :filename => filename,
                  :transform => { :class => FuelEconomyGuide::ParserB, :year => "19#{yy}".to_i },
                  :errata => 'http://static.brighterplanet.com/science/data/transport/automobiles/fuel_economy_guide/errata.csv') do |attr|
        attr.store 'make_name', :field_name => 'make'
        attr.store 'model_name', :field_name => 'model'
        attr.store 'year'
        attr.store 'fuel_type_code', :field_name => 'fuel_type'
        attr.store 'raw_fuel_efficiency_highway', :field_name => 'unadj_hwy_mpg', :from_units => :miles_per_gallon, :to_units => :kilometres_per_litre
        attr.store 'raw_fuel_efficiency_city', :field_name => 'unadj_city_mpg', :from_units => :miles_per_gallon, :to_units => :kilometres_per_litre
        attr.store 'cylinders', :field_name => 'no_cyc'
        attr.store 'drive', :field_name => 'drive_system'
        attr.store 'carline_mfr_code'
        attr.store 'vi_mfr_code'
        attr.store 'carline_code'
        attr.store 'carline_class_code', :field_name => 'carline_clss'
        attr.store 'transmission'
        attr.store 'speeds'
        attr.store 'turbo'
        attr.store 'supercharger'
        attr.store 'injection'
        attr.store 'displacement'
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
                                :errata => 'http://static.brighterplanet.com/science/data/transport/automobiles/fuel_economy_guide/errata.csv') do |attr|
        attr.store 'make_name', :field_name => 'make'
        attr.store 'model_name', :field_name => 'model'
        attr.store 'fuel_type_code', :field_name => 'fl'
        attr.store 'raw_fuel_efficiency_highway', :field_name => 'uhwy', :from_units => :miles_per_gallon, :to_units => :kilometres_per_litre
        attr.store 'raw_fuel_efficiency_city', :field_name => 'ucty', :from_units => :miles_per_gallon, :to_units => :kilometres_per_litre
        attr.store 'cylinders', :field_name => 'cyl'
        attr.store 'displacement', :field_name => 'displ'
        attr.store 'carline_class_code', :field_name => 'cls' if year >= 2000
        attr.store 'carline_class_name', :field_name => 'Class'
        attr.store 'year'
        attr.store 'transmission'
        attr.store 'speeds'
        attr.store 'turbo'
        attr.store 'supercharger'
        attr.store 'injection'
        attr.store 'drive'
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
                                :errata => 'http://static.brighterplanet.com/science/data/transport/automobiles/fuel_economy_guide/errata.csv') do |attr|
        attr.store 'make_name', :field_name => 'make'
        attr.store 'model_name', :field_name => 'model'
        attr.store 'fuel_type_code', :field_name => 'FUEL TYPE'
        attr.store 'raw_fuel_efficiency_highway', :field_name => 'UNRND HWY (EPA)', :from_units => :miles_per_gallon, :to_units => :kilometres_per_litre
        attr.store 'raw_fuel_efficiency_city', :field_name => 'UNRND CITY (EPA)', :from_units => :miles_per_gallon, :to_units => :kilometres_per_litre
        attr.store 'cylinders', :field_name => 'NUMB CYL'
        attr.store 'displacement', :field_name => 'DISPLACEMENT'
        attr.store 'carline_class_code', :field_name => 'CLS'
        attr.store 'carline_class_name', :field_name => 'CLASS'
        attr.store 'year'
        attr.store 'transmission'
        attr.store 'speeds'
        attr.store 'turbo'
        attr.store 'supercharger'
        attr.store 'injection'
        attr.store 'drive'
      end
    end
    
    # associate :make, :key => :original_automobile_make_name, :foreign_key => :name
    # derive :automobile_model_id # creates models by name
    # associate :model_year, :key => :original_automobile_model_year_year, :foreign_key => :year
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
  
  class << self
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
end

class Country < ActiveRecord::Base
  set_primary_key :iso_3166
  
  data_miner do
    unique_index 'iso_3166'
    
    import 'The official ISO country list', :url => 'http://www.iso.org/iso/list-en1-semic-3.txt', :skip => 2, :headers => false, :delimiter => ';' do |attr|
      attr.store 'iso_3166', :field_number => 1
      attr.store 'name', :field_number => 0
    end
    
    import 'A Princeton dataset with better capitalization', :url => 'http://www.cs.princeton.edu/introcs/data/iso3166.csv' do |attr|
      attr.store 'iso_3166', :field_name => 'country code'
      attr.store 'name', :field_name => 'country'
    end
  end
end

class Airport < ActiveRecord::Base
  set_primary_key :iata_code
  # belongs_to :country
  
  data_miner do
    unique_index 'iata_code'
    
    import :url => 'http://openflights.svn.sourceforge.net/viewvc/openflights/openflights/data/airports.dat', :headers => false, :select => lambda { |row| row[4].present? } do |attr|
      attr.store 'name', :field_number => 1
      attr.store 'city', :field_number => 2
      attr.store 'country_name', :field_number => 3
      attr.store 'iata_code', :field_number => 4
      attr.store 'latitude', :field_number => 6
      attr.store 'longitude', :field_number => 7
    end
  end
end

class CensusRegion < ActiveRecord::Base
  set_primary_key :number
  
  data_miner do
    unique_index 'number'
    
    import :url => 'http://www.census.gov/popest/geographic/codes02.csv', :skip => 9, :select => lambda { |row| row['Region'].to_i > 0 and row['Division'].to_s.strip == 'X'} do |attr|
      attr.store 'name', :field_name => 'Name'
      attr.store 'number', :field_name => 'Region'
    end
    
    # pretend this is a different data source
    # fake! just for testing purposes
    import :url => 'http://www.census.gov/popest/geographic/codes02.csv', :skip => 9, :select => lambda { |row| row['Region'].to_i > 0 and row['Division'].to_s.strip == 'X'} do |attr|
      attr.store 'name', :field_name => 'Name'
      attr.store 'number', :field_name => 'Region'
    end
  end
end

# smaller than a region
class CensusDivision < ActiveRecord::Base
  set_primary_key :number
  # belongs_to :census_region
  # has_many :states
  # has_many :zip_codes, :through => :states
  # has_many :climate_divisions, :through => :states
  # has_many :residence_survey_responses
  
  data_miner do
    unique_index 'number'
    
    import :url => 'http://www.census.gov/popest/geographic/codes02.csv', :skip => 9, :select => lambda { |row| row['Division'].to_s.strip != 'X' and row['FIPS CODE STATE'].to_s.strip == 'X'} do |attr|
      attr.store 'name', :field_name => 'Name'
      attr.store 'number', :field_name => 'Division'
      attr.store 'census_region_number', :field_name => 'Region'
      attr.store 'census_region_name', :field_name => 'Region', :dictionary => { :input => 'number', :output => 'name', :url => 'http://data.brighterplanet.com/census_regions.csv' }
    end
  end
end

class ResidentialEnergyConsumptionSurveyResponse < ActiveRecord::Base
  set_primary_key :department_of_energy_identifier
  
  data_miner do
    unique_index 'department_of_energy_identifier'
    
    process 'Define some unit conversions' do
      Conversions.register :kbtus, :joules, 1_000.0 * 1_055.05585
      Conversions.register :square_feet, :square_metres, 0.09290304
    end
    
    # conversions are NOT performed here, since we first have to zero out legitimate skips
    # otherwise you will get values like "999 pounds = 453.138778 kilograms" (where 999 is really a legit skip)
    import 'RECs 2005 (but not converting units to metric just yet)', :url => 'http://www.eia.doe.gov/emeu/recs/recspubuse05/datafiles/RECS05alldata.csv', :headers => :upcase do |attr|
      attr.store 'department_of_energy_identifier', :field_name => 'DOEID'
      
      attr.store 'residence_class', :field_name => 'TYPEHUQ', :dictionary => { :input => 'Code', :output => 'Description', :url => 'http://github.com/brighterplanet/manually_curated_data/raw/master/typehuq/typehuq.csv' }
      attr.store 'construction_year', :field_name => 'YEARMADE', :dictionary => { :input => 'Code', :sprintf => '%02d', :output => 'Date in the middle (synthetic)', :url => 'http://github.com/brighterplanet/manually_curated_data/raw/master/yearmade/yearmade.csv' }
      attr.store 'construction_period', :field_name => 'YEARMADE', :dictionary => { :input => 'Code', :sprintf => '%02d', :output => 'Description', :url => 'http://github.com/brighterplanet/manually_curated_data/raw/master/yearmade/yearmade.csv' }
      attr.store 'urbanity', :field_name => 'URBRUR', :dictionary => { :input => 'Code', :output => 'Description', :url => 'http://github.com/brighterplanet/manually_curated_data/raw/master/urbrur/urbrur.csv' }
      attr.store 'dishwasher_use', :field_name => 'DWASHUSE', :dictionary => { :input => 'Code', :output => 'Description', :url => 'http://github.com/brighterplanet/manually_curated_data/raw/master/dwashuse/dwashuse.csv' }
      attr.store 'central_ac_use', :field_name => 'USECENAC', :dictionary => { :input => 'Code', :output => 'Description', :url => 'http://github.com/brighterplanet/manually_curated_data/raw/master/usecenac/usecenac.csv' }
      attr.store 'window_ac_use', :field_name => 'USEWWAC', :dictionary => { :input => 'Code', :output => 'Description', :url => 'http://github.com/brighterplanet/manually_curated_data/raw/master/usewwac/usewwac.csv' }
      attr.store 'clothes_washer_use', :field_name => 'WASHLOAD', :dictionary => { :input => 'Code', :output => 'Description', :url => 'http://github.com/brighterplanet/manually_curated_data/raw/master/washload/washload.csv' }
      attr.store 'clothes_dryer_use', :field_name => 'DRYRUSE', :dictionary => { :input => 'Code', :output => 'Description', :url => 'http://github.com/brighterplanet/manually_curated_data/raw/master/dryruse/dryruse.csv' }
      
      attr.store 'census_division_number', :field_name => 'DIVISION'
      attr.store 'census_division_name', :field_name => 'DIVISION', :dictionary => { :input => 'number', :output => 'name', :url => 'http://data.brighterplanet.com/census_divisions.csv' }
      attr.store 'census_region_number', :field_name => 'DIVISION', :dictionary => { :input => 'number', :output => 'census_region_number', :url => 'http://data.brighterplanet.com/census_divisions.csv' }
      attr.store 'census_region_name', :field_name => 'DIVISION', :dictionary => { :input => 'number', :output => 'census_region_name', :url => 'http://data.brighterplanet.com/census_divisions.csv' }
      
      attr.store 'floorspace', :field_name => 'TOTSQFT'
      attr.store 'residents', :field_name => 'NHSLDMEM'
      attr.store 'ownership', :field_name => 'KOWNRENT'
      attr.store 'thermostat_programmability', :field_name => 'PROTHERM'
      attr.store 'refrigerator_count', :field_name => 'NUMFRIG'
      attr.store 'freezer_count', :field_name => 'NUMFREEZ'
      attr.store 'heating_degree_days', :field_name => 'HD65'
      attr.store 'cooling_degree_days', :field_name => 'CD65'
      attr.store 'annual_energy_from_fuel_oil_for_heating_space', :field_name => 'BTUFOSPH'
      attr.store 'annual_energy_from_fuel_oil_for_heating_water', :field_name => 'BTUFOWTH'
      attr.store 'annual_energy_from_fuel_oil_for_appliances', :field_name => 'BTUFOAPL'
      attr.store 'annual_energy_from_natural_gas_for_heating_space', :field_name => 'BTUNGSPH'
      attr.store 'annual_energy_from_natural_gas_for_heating_water', :field_name => 'BTUNGWTH'
      attr.store 'annual_energy_from_natural_gas_for_appliances', :field_name => 'BTUNGAPL'
      attr.store 'annual_energy_from_propane_for_heating_space', :field_name => 'BTULPSPH'
      attr.store 'annual_energy_from_propane_for_heating_water', :field_name => 'BTULPWTH'
      attr.store 'annual_energy_from_propane_for_appliances', :field_name => 'BTULPAPL'
      attr.store 'annual_energy_from_wood', :field_name => 'BTUWOOD'
      attr.store 'annual_energy_from_kerosene', :field_name => 'BTUKER'
      attr.store 'annual_energy_from_electricity_for_clothes_driers', :field_name => 'BTUELCDR'
      attr.store 'annual_energy_from_electricity_for_dishwashers', :field_name => 'BTUELDWH'
      attr.store 'annual_energy_from_electricity_for_freezers', :field_name => 'BTUELFZZ'
      attr.store 'annual_energy_from_electricity_for_refrigerators', :field_name => 'BTUELRFG'
      attr.store 'annual_energy_from_electricity_for_air_conditioners', :field_name => 'BTUELCOL'
      attr.store 'annual_energy_from_electricity_for_heating_space', :field_name => 'BTUELSPH'
      attr.store 'annual_energy_from_electricity_for_heating_water', :field_name => 'BTUELWTH'
      attr.store 'annual_energy_from_electricity_for_other_appliances', :field_name => 'BTUELAPL'
      attr.store 'weighting', :field_name => 'NWEIGHT'
      attr.store 'total_rooms', :field_name => 'TOTROOMS'
      attr.store 'bathrooms', :field_name => 'NCOMBATH'
      attr.store 'halfbaths', :field_name => 'NHAFBATH'
      attr.store 'heated_garage', :field_name => 'GARGHEAT'
      attr.store 'attached_1car_garage', :field_name => 'GARAGE1C'
      attr.store 'detached_1car_garage', :field_name => 'DGARG1C'
      attr.store 'attached_2car_garage', :field_name => 'GARAGE2C'
      attr.store 'detached_2car_garage', :field_name => 'DGARG2C'
      attr.store 'attached_3car_garage', :field_name => 'GARAGE3C'
      attr.store 'detached_3car_garage', :field_name => 'DGARG3C'
      attr.store 'lights_on_1_to_4_hours', :field_name => 'LGT1'
      attr.store 'efficient_lights_on_1_to_4_hours', :field_name => 'LGT1EE'
      attr.store 'lights_on_4_to_12_hours', :field_name => 'LGT4'
      attr.store 'efficient_lights_on_4_to_12_hours', :field_name => 'LGT4EE'
      attr.store 'lights_on_over_12_hours', :field_name => 'LGT12'
      attr.store 'efficient_lights_on_over_12_hours', :field_name => 'LGT12EE'
      attr.store 'outdoor_all_night_lights', :field_name => 'NOUTLGTNT'
      attr.store 'outdoor_all_night_gas_lights', :field_name => 'NGASLIGHT'
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

# todo: have somebody properly organize these
class DataMinerTest < Test::Unit::TestCase
  if ENV['FAST'] == 'true'
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
    
    should "assume that no unique indices means it wants a big hash" do
      assert_raises DataMiner::MissingHashColumn do
        class IncompleteCountry < ActiveRecord::Base
          set_table_name 'countries'
        
          data_miner do
            # no unique index
  
            # get a complete list
            import :url => 'http://www.iso.org/iso/list-en1-semic-3.txt', :skip => 2, :headers => false, :delimiter => ';' do |attr|
              attr.store 'iso_3166', :field_number => 1
              attr.store 'name', :field_number => 0
            end
  
            # get nicer names
            import :url => 'http://www.cs.princeton.edu/introcs/data/iso3166.csv' do |attr|
              attr.store 'iso_3166', :field_name => 'country code'
              attr.store 'name', :field_name => 'country'
            end
          end
        end
      end
    end
  
    should "hash things if no unique index is listed" do
      AutomobileVariant.data_miner_config.runnables[0].run(nil)
      assert AutomobileVariant.first.row_hash.present?
    end
  
    should "process a callback block instead of a method" do
      AutomobileVariant.delete_all
      AutomobileVariant.data_miner_config.runnables[0].run(nil)
      assert !AutomobileVariant.first.fuel_efficiency_city.present?
      AutomobileVariant.data_miner_config.runnables.last.run(nil)
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
  
  if ENV['SLOW'] == 'true'
    should "import using a dictionary" do
      DataMiner.run :resource_names => %w{ ResidentialEnergyConsumptionSurveyResponse }
      assert ResidentialEnergyConsumptionSurveyResponse.find(6).residence_class.starts_with?('Single-family detached house')
    end
    
    should "mine multiple classes in the correct order" do
      DataMiner.run
      uy = Country.find_by_iso_3166('UY')
      assert_equal 'Uruguay', uy.name
    end
  end
end
