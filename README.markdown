# data_miner

Download, pull out of a ZIP/TAR/GZ/BZ2 archive, parse, correct, and import XLS, ODS, XML, CSV, HTML, etc. into your ActiveRecord models.

Tested in MRI 1.8.7+, MRI 1.9.2+, and JRuby 1.6.7+. Thread safe.

## Real-world usage

<p><a href="http://brighterplanet.com"><img src="https://s3.amazonaws.com/static.brighterplanet.com/assets/logos/flush-left/inline/green/rasterized/brighter_planet-160-transparent.png" alt="Brighter Planet logo"/></a></p>

We use `data_miner` for [data science at Brighter Planet](http://brighterplanet.com/research) and in production at

* [Brighter Planet's reference data web service](http://data.brighterplanet.com)
* [Brighter Planet's impact estimate web service](http://impact.brighterplanet.com)

The killer combination for us is:

1. [`active_record_inline_schema`](https://github.com/seamusabshere/active_record_inline_schema) - define table structure
2. [`remote_table`](https://github.com/seamusabshere/remote_table) - download data and parse it
3. [`errata`](https://github.com/seamusabshere/errata) - apply corrections in a transparent way
4. [`data_miner`](https://github.com/seamusabshere/data_miner) (this library!) - import data idempotently

## Documentation

Check out the [extensive documentation](http://rdoc.info/github/seamusabshere/data_miner).

## Quick start

You define <code>data_miner</code> blocks in your ActiveRecord models. For example, in <code>app/models/country.rb</code>:

    class Country < ActiveRecord::Base
      self.primary_key = 'iso_3166_code'

      # the "col" class method is provided by a different library - active_record_inline_schema
      col :iso_3166_code                            # alpha-2 2-letter like GB
      col :iso_3166_numeric_code, :type => :integer # numeric like 826; aka UN M49 code
      col :iso_3166_alpha_3_code                    # 3-letter like GBR
      col :name
  
      data_miner do
        # auto_upgrade! is provided by active_record_inline_schema
        process :auto_upgrade!

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

The [`earth` library](https://github.com/brighterplanet/earth) has dozens of real-life examples showing how to download, pull out of a ZIP/TAR/BZ2 archive, parse, correct, and import CSVs, fixed-width files, ODS, XLS, XLSX, even HTML and XML:

<table>
  <tr>
    <th>Model</th>
    <th>Highlights</th>
    <th>Reference</th>
  </tr>
  <tr>
    <td><a href="http://data.brighterplanet.com/aircraft">Aircraft</a></td>
    <td>parsing Microsoft Frontpage HTML (!)</td>
    <td><a href="https://github.com/brighterplanet/earth/blob/master/lib/earth/air/aircraft/data_miner.rb">data_miner.rb</a></td>
  </tr>
  <tr>
    <td><a href="http://data.brighterplanet.com/airports">Airports</a></td>
    <td>forcing column names and use of <code>:select</code> block (<code>Proc</code>)</td>
    <td><a href="https://github.com/brighterplanet/earth/blob/master/lib/earth/air/airport/data_miner.rb">data_miner.rb</a></td>
  </tr>
  <tr>
    <td><a href="http://data.brighterplanet.com/automobile_make_model_year_variants">Automobile model variants</a></td>
    <td>super advanced usage of "custom parser" and errata</td>
    <td><a href="https://github.com/brighterplanet/earth/blob/master/lib/earth/automobile/automobile_make_model_year_variant/data_miner.rb">data_miner.rb</a></td>
  </tr>
  <tr>
    <td><a href="http://data.brighterplanet.com/countries">Country</a></td>
    <td>parsing CSV and a few other tricks</td>
    <td><a href="https://github.com/brighterplanet/earth/blob/master/lib/earth/locality/country/data_miner.rb">data_miner.rb</a></td>
  </tr>
  <tr>
    <td><a href="http://data.brighterplanet.com/egrid_regions">EGRID regions</a></td>
    <td>parsing XLS</td>
    <td><a href="https://github.com/brighterplanet/earth/blob/master/lib/earth/locality/egrid_region/data_miner.rb">data_miner.rb</a></td>
  </tr>
  <tr>
    <td><a href="http://data.brighterplanet.com/flight_segments">Flight segment (stage)</a></td>
    <td>super advanced usage of POSTing form data</td>
    <td><a href="https://github.com/brighterplanet/earth/blob/master/lib/earth/air/flight_segment/data_miner.rb">data_miner.rb</a></td>
  </tr>
  <tr>
    <td><a href="http://data.brighterplanet.com/zip_codes">Zip codes</a></td>
    <td>downloading a ZIP file and pulling an XLSX out of it</td>
    <td><a href="https://github.com/brighterplanet/earth/blob/master/lib/earth/locality/zip_code.rb">data_miner.rb</a></td>
  </tr>
</table>

And many more - look for the `data_miner.rb` file that corresponds to each model. Note that you would normally put the `data_miner` declaration right inside the ActiveRecord model file... it's kept separate in `earth` so that loading it is optional.

## Authors

* Seamus Abshere <seamus@abshere.net>
* Andy Rossmeissl <andy@rossmeissl.net>
* Derek Kastner <dkastner@gmail.com>
* Ian Hough <ijhough@gmail.com>
* Tower He <towerhe@gmail.com>

## Wishlist

* Make the tests real unit tests
* sql steps shouldn't shell out if binaries are missing

## Copyright

Copyright (c) 2013 Seamus Abshere
