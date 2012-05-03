# data_miner

Download and import XLS, ODS, XML, CSV, etc. into your ActiveRecord models.

Tested in MRI 1.8.7+, MRI 1.9.2+, and JRuby 1.6.7+. Thread safe.

## Real-world usage

<p><a href="http://brighterplanet.com"><img src="https://s3.amazonaws.com/static.brighterplanet.com/assets/logos/flush-left/inline/green/rasterized/brighter_planet-160-transparent.png" alt="Brighter Planet logo"/></a></p>

We use `data_miner` for [data science at Brighter Planet](http://brighterplanet.com/research) and in production at

* [Brighter Planet's reference data web service](http://data.brighterplanet.com)
* [Brighter Planet's impact estimate web service](http://impact.brighterplanet.com)

The killer combination:

1. [`active_record_inline_schema`](https://github.com/seamusabshere/active_record_inline_schema) - define table structure
2. [`remote_table`](https://github.com/seamusabshere/remote_table) - download data and parse it
3. [`errata`](https://github.com/seamusabshere/errata) - apply corrections in a transparent way
4. [`data_miner`](https://github.com/seamusabshere/remote_table) (this library!) - import data idempotently

## Quick start

You define <tt>data_miner</tt> blocks in your ActiveRecord models. For example, in <tt>app/models/country.rb</tt>:

    class Country < ActiveRecord::Base
      self.primary_key =  'iso_3166_code'
  
      data_miner do
        import("OpenGeoCode.org's Country Codes to Country Names list",
               :url => 'http://opengeocode.org/download/countrynames.txt',
               :format => :delimited,
               :delimiter => '; ',
               :headers => false,
               :skip => 22) do
          key   :iso_3166_code, :field_number => 0
          store :iso_3166_alpha_3_code, :field_number => 1
          store :iso_3166_numeric_code, :field_number => 2
          store :name, :field_number => 5
        end
      end
    end

Now you can run:

  >> Country.run_data_miner!
  => nil

## More advanced usage

The [`earth` library](https://github.com/brighterplanet/earth) has dozens of real-life examples showing how to download, parse, correct, and import CSVs, fixed-width files, ODS, XLS, XLSX, even HTML and XML:

* https://github.com/brighterplanet/earth/blob/master/lib/earth/locality/country/data_miner.rb - CSV and a few other tricks
* https://github.com/brighterplanet/earth/blob/master/lib/earth/locality/egrid_region/data_miner.rb - XLS
* https://github.com/brighterplanet/earth/blob/master/lib/earth/locality/zip_code.rb - pulling an XLSX out of a ZIP file
* https://github.com/brighterplanet/earth/blob/master/lib/earth/air/aircraft/data_miner.rb - parsing Microsoft Frontpage HTML
* https://github.com/brighterplanet/earth/blob/master/lib/earth/automobile/automobile_make_model_year_variant/data_miner.rb - super advanced usage showing "custom parser" and errata usage
* https://github.com/brighterplanet/earth/blob/master/lib/earth/air/flight_segment/data_miner.rb - super advanced usage showing submission of form data
* and many more - look for the `data_miner.rb` file that corresponds to each model.

## Authors

* Seamus Abshere <seamus@abshere.net>
* Andy Rossmeissl <andy@rossmeissl.net>
* Derek Kastner <dkastner@gmail.com>
* Ian Hough <ijhough@gmail.com>

## Copyright

Copyright (c) 2012 Brighter Planet. See LICENSE for details.
