# gis_scraper
[![Build status](https://secure.travis-ci.org/MatzFan/gis_scraper.svg)](http://travis-ci.org/MatzFan/gis_scraper)

Utility to scrape ArcGIS MapServer data using REST API.

ArcGIS MapServer REST queries are limited to 1,000 objects in some cases. This tool makes repeated calls until all data for a given layer is extracted. It then merges the resulting JSON files into a single file. This allows GIS clients like QGIS to add a layer from a single file.

**Usage**

The executable is called 'gis' and takes one required arguement - the MapServer URL - and an optional second arg to specify the path of the output file. If omitted the file will be saved in current directory. Example:

```
gis http://gps.digimap.gg/arcgis/rest/services/StatesOfJersey/JerseyMappingOL/MapServer/0 ~/Desktop
```

**Specification and Tests**

rspec spec --format documentation

