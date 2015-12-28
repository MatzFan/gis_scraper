# gis_scraper Ruby Gem
[![Gem Version](https://badge.fury.io/rb/gis_scraper.svg)](http://badge.fury.io/rb/gis_scraper)
[![Build status](https://secure.travis-ci.org/MatzFan/gis_scraper.svg)](http://travis-ci.org/MatzFan/gis_scraper)

Utility to recursively scrape ArcGIS MapServer data using REST API.

ArcGIS MapServer REST queries are limited to 1,000 objects in some cases. This tool makes repeated calls until all data for a given layer (and all sub-layers) is extracted. Output can be JSON file format or (feature in development) data may be written directly to a database. GIS clients like QGIS can be configured to read the resulting layer data from the database tables.

## Requirements

Ruby 2.0 or above - see Travis badge for tested Ruby versions.

For data import to a database [GDAL](http://gdal.org) must be installed and specifically the [ogr2ogr](http://www.gdal.org/ogr2ogr.html) executable must be available in your path.

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

Configuration options may be set via a hash or specified in a Yaml file. The following options are available:

- ```:threads``` Scraping is multi-threaded. The number of threads to use may be set with this option (default 8)
- ```:output_path```    For JSON output, the path used to write files to (default is current working directory)

**To set via a hash**

```Ruby
GisScraper.configure(:threads => 16)
```

**Using a Yaml configuration file**

```Ruby
GisScraper.configure_with 'path-to-Yaml-file'
```

```Ruby
GisScraper.config # returns the hash of configuration values
```

## Usage

A Layer object must be instantiated with one required arg - a MapServer/Layer URL (ending in an integer representing the layer number). Example:

```
layer = Layer.new('http://gps.digimap.gg/arcgis/rest/services/StatesOfJersey/JerseyMappingOL/MapServer/0')
```

An optional second argument for the output path for JSON files may be specified. If so this overides the configuration option. Example:

```
layer = Layer.new('http://gps.digimap.gg/arcgis/rest/services/StatesOfJersey/JerseyMappingOL/MapServer/0', '~/Desktop')
```

**JSON output**

```
layer.output_json
```

If the layer is type 'Feature Layer', a single file of JSON data will be saved (named the same as the layer). If the layer is type 'Group Layer', the sub-group structure is traversed recursively thus: Directories for each sub-group layer are created and JSON data files for each constituent feature layer written to them.

**Output to a database**

```
layer.output_to_db
```

## Specification and Tests

For the full specification clone this repo and run:

`rake spec`

## Contributing

Bug reports, pull requests (and feature requests) are welcome on GitHub at https://github.com/MatzFan/gis_scraper.

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses)
