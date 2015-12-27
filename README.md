# gis_scraper Ruby Gem
[![Gem Version](https://badge.fury.io/rb/gis_scraper.svg)](http://badge.fury.io/rb/gis_scraper)
[![Build status](https://secure.travis-ci.org/MatzFan/gis_scraper.svg)](http://travis-ci.org/MatzFan/gis_scraper)

Utility to recursively scrape ArcGIS MapServer data using REST API.

ArcGIS MapServer REST queries are limited to 1,000 objects in some cases. This tool makes repeated calls until all data for a given layer (and all sub-layers) is extracted. Output can be JSON file format or (feature in development) data may be written directly to a database. GIS clients like QGIS can be configured to read the resulting layer data from the database tables.

## Requirements

See Travis badge for tested Ruby versions.

For data import to a database [GDAL](http://gdal.org) must be installed and specifically the ogr2ogr executable must be available in your path.

# Installation

Add this line to your application's Gemfile:

```ruby
gem 'gis_scraper'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install gis_scraper

## Configuration

Config settings may be set via a hash or a Yaml file.

**Via a hash**

Scraping is multi-threaded. The number of threads to use may be set (default 8):
```Ruby
GisScraper.configure(:threads => 16)
```

**From a Yaml configuration file**
```Ruby
GisScraper.configure_with 'path-to-Yaml-file'
```

```Ruby
GisScraper.config # returns the configuration hash
```

## Usage

The executable is called 'gisget' and takes one required arg - a MapServer/Layer URL (ending in an integer representing the layer number). An optional file output path may also be specified. If omitted the file will be saved in current directory. Example:

```
gisget http://gps.digimap.gg/arcgis/rest/services/StatesOfJersey/JerseyMappingOL/MapServer/0 ~/Desktop
```

If the layer is type 'Feature Layer', a single file of JSON data will be saved (named the same as the layer). If the layer is type 'Group Layer', the sub-group structure is traversed recursively thus: Directories for each sub-group layer are created and JSON data files for each constituent feature layer written to them.

## Specification and Tests

For the full specification clone this repo and run:

`rake spec`

## Contributing

Bug reports, pull requests (and feature requests) are welcome on GitHub at https://github.com/MatzFan/gis_scraper.

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses

