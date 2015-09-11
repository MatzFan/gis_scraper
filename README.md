# gis_scraper
[![Build status](https://secure.travis-ci.org/MatzFan/gis_scraper.svg)](http://travis-ci.org/MatzFan/gis_scraper)

Utility to recursively scrape ArcGIS MapServer data using REST API.

ArcGIS MapServer REST queries are limited to 1,000 objects in some cases. This tool makes repeated calls until all data for a given layer is extracted. It then merges the resulting JSON files into a single file. This allows GIS clients like QGIS to add a layer from a single file.

**Usage**

The executable is called 'gis' and takes one required arg - a MapServer/Layer URL (ending in an integer representing the layer number). An optional file output path may also be specified. If omitted the file will be saved in current directory. Example:

```
gis http://gps.digimap.gg/arcgis/rest/services/StatesOfJersey/JerseyMappingOL/MapServer/0 ~/Desktop
```

If the layer is type 'Feature Layer', a single file of JSON data will be saved (named the same as the layer). If the layer is type 'Group Layer', the sub-group structure is traversed recursively thus: Directories for each sub-group layer are created and JSON data files for each constituent feature layer written to them.

**Specification and Tests**

rspec spec --format documentation

