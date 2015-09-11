require 'layer'

describe Layer do

  let(:feature_layer) { Layer.new 'http://gps.digimap.gg/arcgis/rest/services/StatesOfJersey/JerseyMappingOL/MapServer/0' }
  let(:group_layer) { Layer.new('http://gps.digimap.gg/arcgis/rest/services/JerseyUtilities/JerseyUtilities/MapServer/146', __dir__) }
  let(:no_layer_id_url) { Layer.new 'no/layer/number/specified/MapServer' }
  let(:not_map_server_url) { Layer.new '"MapServer"/missing/42' }
  let(:feature_layer_with_path) { Layer.new('http://gps.digimap.gg/arcgis/rest/services/StatesOfJersey/JerseyPlanning/MapServer/11', __dir__) }
  let(:layer_with_sub_group_layers) { Layer.new 'http://gps.digimap.gg/arcgis/rest/services/JerseyUtilities/JerseyUtilities/MapServer/129', __dir__ }
  sub_layers = [{"id"=>130, "name"=>"High Pressure"}, {"id"=>133, "name"=>"Medium Pressure"}, {"id"=>136, "name"=>"Low Pressure"}]

  let(:scraper_double) { instance_double 'FeatureScraper' }

  context '#new(url)' do
    it 'raises ArgumentError "URL must end with layer id" with a URL not ending in an integer' do
      expect(->{no_layer_id_url}).to raise_error ArgumentError, 'URL must end with layer id'
    end

    it 'raises ArgumentError "Bad MapServer URL" with a URL not ending in an integer' do
      expect(->{not_map_server_url}).to raise_error ArgumentError, 'Bad MapServer URL'
    end

    it 'instantiates an instance of the class with no second arg' do
      expect(feature_layer.class).to eq Layer
    end
  end

  context '#type' do
    it 'returns the layer type for a feature layer' do
      expect(feature_layer.type).to eq 'Feature Layer'
    end

    it 'returns the layer type for a group layer' do
      expect(group_layer.type).to eq 'Group Layer'
    end
  end

  context '#sub_layer_id_names' do
    it 'returns an empty list for a feature layer (which have no sub layers)' do
      expect(feature_layer.sub_layer_id_names).to eq []
    end

    it 'returns a list of the sublayer hashes for :id, :name for a group layer, if any' do
      expect(layer_with_sub_group_layers.sub_layer_id_names).to eq sub_layers
    end
  end

  context '#group_layer_ids' do
    it 'returns a list of the layer id\'s at this server' do
      expect(group_layer.layer_ids).to eq [147, 148, 149, 150, 151, 152, 153, 154]
    end
  end

  context '#layer_name_list' do
    it 'returns a list of the layer names for a Feature Layer' do
      allow(FeatureScraper).to receive(:new) { scraper_double }
      allow(scraper_double).to receive(:name) { 'layer name' }
      expect(feature_layer.layer_name_list).to eq ['layer name']
    end

    it 'returns a list of the layer names for a Group Layer' do
      allow(FeatureScraper).to receive(:new) { scraper_double }
      allow(scraper_double).to receive(:name).and_return('l1', 'l2', 'l3', 'l4', 'l5', 'l6', 'l7', 'l8')
      expect(group_layer.layer_name_list).to eq %w(l1 l2 l3 l4 l5 l6 l7 l8)
    end
  end

  context '#layers_data_json_list' do
    it 'returns a single item list of the json data for a Feature Layer' do
      allow(FeatureScraper).to receive(:new) { scraper_double }
      allow(scraper_double).to receive(:json_data) { {} }
      expect(feature_layer.layers_data_json_list).to eq [{}]
    end

    it 'returns a list of the json data for each sub layer in a Group Layer' do
      allow(FeatureScraper).to receive(:new) { scraper_double }
      allow(scraper_double).to receive(:json_data) { {} }
      expect(group_layer.layers_data_json_list).to eq [{}, {}, {}, {}, {}, {} ,{}, {}]
    end
  end

  context '#write_feature_files' do
    it "writes a feature layer's data to a JSON file in the path specified or '.'" do
      file_name = 'Aircraft Noise Zone 1.json'
      begin
        feature_layer_with_path.write_feature_files
        expect(`ls ./spec`).to include file_name
      ensure
        File.delete File.new(File.join __dir__, file_name) rescue nil # cleanup
      end
    end

    it "writes a group layer's data (for all IMMEDIATE child feature layers) to JSON files in the path specified or '.'" do
      file_names = %w(VC500.json SWACable185.json SWACable120.json PrimaryDuct.json MMSQ95or150.json LV501.json FibreOpticCable.json CommsCable.json)
      begin
        group_layer.write_feature_files
        file_names.all? { |file| expect(`ls ./spec`).to include file }
      ensure
        file_names.each { |file_name| File.delete(File.new(File.join __dir__, file_name)) rescue nil } # cleanup
      end
    end
  end

  context '#sub_layer(id)' do
    it 'returns the a Layer object for the given the sub layer id' do
      expect(layer_with_sub_group_layers.sub_layer(130, __dir__).class). to eq Layer
    end
  end

  context '#write' do
    it 'calls #write_feature_files for a feature layer' do
      layer = feature_layer
      allow(layer).to receive(:write_feature_files)
      expect(->{layer.write}).not_to raise_error
    end

    it "creates sub directories mirroring sub-group structure" do
      dir_names = ['High Pressure', 'Medium Pressure', 'Low Pressure']
      allow_any_instance_of(Layer).to receive :write_feature_files # stub recursive instances, so nothing is scraped!!
      begin
        layer_with_sub_group_layers.write
        dir_names.all? { |dir| expect(`ls ./spec`).to include dir }
      ensure
        dir_names.each { |dir_name| FileUtils.rm_rf "#{__dir__}/#{dir_name}" rescue nil } # cleanup
      end
    end
  end

end
