#!/usr/bin/env ruby

require 'json'
require_relative 'lib/scraper'

scraper = Scraper.new('StatesOfJersey/JerseyMappingOL', 0)
json = scraper.all_data.to_json
File.open("/Users/me/Desktop/#{scraper.name}.json", 'w') { |f| f.write json }
