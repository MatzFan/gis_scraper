require 'layer'

describe Layer do

  let(:feature_layer) { Layer.new 'http://gps.digimap.gg/arcgis/rest/services/StatesOfJersey/JerseyMappingOL/MapServer/0' }
  let(:group_layer) { Layer.new 'http://gps.digimap.gg/arcgis/rest/services/JerseyUtilities/JerseyUtilities/MapServer/139' }
  let(:no_layer_id_url) { Layer.new 'no/layer/number/specified/MapServer' }
  let(:not_map_server_url) { Layer.new '"MapServer"/missing/42' }

  let(:scraper_double) { instance_double 'Scraper' }

  context '#new(url)' do
    it 'raises ArgumentError "URL must end with layer id" with a URL not ending in an integer' do
      expect(->{no_layer_id_url}).to raise_error ArgumentError, 'URL must end with layer id'
    end

    it 'raises ArgumentError "Not a MapServer URL" with a URL not ending in an integer' do
      expect(->{not_map_server_url}).to raise_error ArgumentError, 'Not a MapServer URL'
    end

    it 'instantiates an instance of the class with no second arg' do
      expect(feature_layer.class).to eq Layer
    end
  end

  context '#layer_type' do
    it 'returns the layer type for a feature layer' do
      expect(feature_layer.layer_type).to eq 'Feature Layer'
    end

    it 'returns the layer type for a group layer' do
      expect(group_layer.layer_type).to eq 'Group Layer'
    end
  end

  context '#group_layer_ids' do
    it 'returns a list of the layer id\'s at this server' do
      expect(group_layer.layer_ids).to eq [140, 141]
    end
  end

  context '#layer_name_list' do
    it 'returns a list of the layer names for a Feature Layer' do
      allow(Scraper).to receive(:new) { scraper_double }
      allow(scraper_double).to receive(:name) { 'layer name' }
      expect(feature_layer.layer_name_list).to eq ['layer name']
    end

    it 'returns a list of the layer names for a Group Layer' do
      allow(Scraper).to receive(:new) { scraper_double }
      allow(scraper_double).to receive(:name).and_return('layer1', 'layer2')
      expect(group_layer.layer_name_list).to eq %w(layer1 layer2)
    end
  end

  context '#layers_data_json_list' do
    it 'returns a single item list of the json data for a Feature Layer' do
      allow(Scraper).to receive(:new) { scraper_double }
      allow(scraper_double).to receive(:json_data) { {} }
      expect(feature_layer.layers_data_json_list).to eq [{}]
    end

    it 'returns a list of the json data for each sub layer in a Group Layer' do
      allow(Scraper).to receive(:new) { scraper_double }
      allow(scraper_double).to receive(:json_data) { {} }
      expect(group_layer.layers_data_json_list).to eq [{}, {}]
    end
  end

end
