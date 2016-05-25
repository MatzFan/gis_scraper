describe FeatureScraper do
  before do
    GisScraper.configure
  end

  root = 'http://gps.digimap.gg/arcgis/rest/services/'
  recursive_layer = root + 'StatesOfJersey/JerseyMappingOL/MapServer/0'
  non_recursive_layer = root + 'JerseyUtilities/JerseyUtilities/MapServer/145'
  simple = 'http://gis.digimap.je/ArcGIS/rest/services/JsyBase/MapServer/34'
  gaz = 'http://gis.digimap.je/ArcGIS/rest/services/Gazetteer/MapServer/0'
  gaz_keys = %w(OBJECTID guid_ logicalstatus Add1 Add2 Add3 Add4 Parish
                Postcode Island UPRN USRN Property_Type Address1 Easting
                Northing Vingtaine Updated)
  let(:scraper) { FeatureScraper.new recursive_layer }
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
                                   'width' => 0.4 }
                    },
      'label' => '',
      'description' => '' }
  end

  context '#new(url)' do
    it 'instantiates an instance of the class' do
      expect(scraper.class).to eq FeatureScraper
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

  context '#form' do
    it 'returns a Mechanize::Form for the layer query page' do
      expect(scraper.send(:form).class).to eq Mechanize::Form
    end
  end

  context '#count' do
    it 'returns the number of records for the layer' do
      expect(scraper.send(:count)).to eq 67_537
    end
  end

  context '#data(records_set_num)' do
    it 'returns a hash of json data' do
      expect(scraper.send(:data, 0).class).to eq Hash
    end

    it 'returns a hash with a "features" key' do
      expect(scraper.send(:data, 0).keys.include?('features')).to eq true
    end

    it "['features'] value is a an array of hashes" do
      expect(scraper.send(:data, 0)['features'].all? do |e|
        e.class == Hash
      end).to eq true
    end

    it 'each hash has keys "attributes" and "geometry". Values are hashes' do
      expect(scraper.send(:data, 0)['features'].all? do |e|
        e['attributes'].class == Hash && e['geometry'].class == Hash
      end).to eq true
    end

    it "['attributes'] is a hash whose keys are the layer fields" do
      expect(FeatureScraper.new(gaz).send(:data, 0)['features'][0]['attributes']
        .keys).to eq gaz_keys
    end

    it 'returns data for the set of records' do
      expect(scraper.send(:data, 67)['features'].count).to eq 537
    end
  end

  context '#features(num_threads)' do
    it 'returns an array of the features data for all layer objects' do
      scraper.instance_variable_set(:@max, 2)
      scraper.instance_variable_set(:@loops, 2)
      expect(scraper.send(:features, 1).count).to eq 4
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
end
