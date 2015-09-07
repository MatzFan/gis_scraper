# gis_scraper

App to scrape ArcGIS MapServer data using REST API.

Queries are limited to 1,000 objects in some cases, so  this tool makes repeated calls until all data for a given layer is extracted. It then merges the resulting JSON files into a single file. This allows GIS clients like QGIS to add a layer from a single file.
