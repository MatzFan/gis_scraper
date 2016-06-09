describe FeatureScraper do
  before do
    GisScraper.configure
  end

  root = 'http://gps.digimap.gg/arcgis/rest/services/'
  recursive_layer = root + 'StatesOfJersey/JerseyMappingOL/MapServer/0'
  non_recursive_layer = root + 'JerseyUtilities/JerseyUtilities/MapServer/145'
  simple = 'http://gis.digimap.je/ArcGIS/rest/services/JsyBase/MapServer/34'
  gaz_url = 'http://gis.digimap.je/ArcGIS/rest/services/Gazetteer/MapServer/0'
  esri_string = 'esriFieldTypeString'

  let(:scraper) { FeatureScraper.new recursive_layer }
  let(:gaz_scraper) { FeatureScraper.new gaz_url }
  let(:bad_url_scraper) { FeatureScraper.new 'garbage' }
  let(:non_recursive_scraper) { FeatureScraper.new non_recursive_layer }
  let(:simple_renderer_scraper) { FeatureScraper.new simple }
  let(:simple_renderer) do
    { 'type' => 'simple',
      'symbol' => { 'type' => 'esriSFS',
                    'style' => 'esriSFSSolid',
                    'color' => [255, 211, 127, 255],
                    'outline' => { 'type' => 'esriSLS',
                                   'style' => 'esriSLSSolid',
                                   'color' => [0, 0, 0, 255],
                                   'width' => 0.4 } },
      'label' => '',
      'description' => '' }
  end

  context '#new(url)' do
    it 'instantiates an instance of the class' do
      s = FeatureScraper.new 'http://gps.digimap.gg/arcgis/rest/services/StatesOfJersey/JerseyMappingOL/MapServer/0'
      expect(s.class).to eq FeatureScraper
    end
  end

  context '#name' do
    it 'returns the name of the layer' do
      expect(scraper.send(:name)). to eq 'Gazetteer'
    end
  end

  context '#pk' do
    it 'returns the pk field, if it is first in the field list' do
      expect(scraper.send(:pk)).to eq 'OBJECTID'
    end

    it 'returns the pk field, if it is elsewhere in the field list' do
      expect(non_recursive_scraper.send(:pk)).to eq 'OBJECTID'
    end
  end

  context '#max' do
    it 'returns the layer API call limit, if key: "maxRecordCount" exits' do
      expect(scraper.send(:max)).to eq 1000
    end

    it 'returns API_CALL_LIMIT value if key: "maxRecordCount" does not exit' do
      FeatureScraper.const_set(:API_CALL_LIMIT, 500)
      expect(simple_renderer_scraper.send(:max)).to eq 500
    end
  end

  context '#count' do
    it 'returns the number of records for the layer' do
      expect(scraper.send(:count)).to eq 67_537
    end
  end

  context '#all_features(num_threads)' do
    it 'returns an array of the features data for all layer objects' do
      scraper.instance_variable_set(:@max, 2)
      scraper.instance_variable_set(:@loops, 2)
      expect(scraper.send(:all_features, 1).count).to eq 4
    end
  end

  context '#json_data', :public do
    it 'returns string of json data for all layer objects' do
      scraper.instance_variable_set(:@max, 2)
      allow(scraper).to receive(:count) { 4 }
      expect(scraper.json_data.class).to eq String
    end
  end

  context '#renderer', :public do
    it 'returns a hash-representation of the renderer' do
      expect(simple_renderer_scraper.send(:renderer)).to eq simple_renderer
    end
  end

  context '#query_without_features' do
    it 'returns a hash of a layer query with features: value empty' do
      features = non_recursive_scraper.send(:query_without_features)['features']
      expect(features).to be_empty
    end

    it 'converts any VARCHAR fields > length 10,485,760 to length 0' do
      fields = gaz_scraper.send(:query_without_features)['fields']
      esri_string_fields = fields.select { |f| f['type'] == esri_string }
      expect(esri_string_fields.all? { |f| f['length'] == 0 }).to eq true
    end
  end
end
