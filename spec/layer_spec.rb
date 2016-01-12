describe Layer do

  before do
    GisScraper.configure(output_path: 'tmp', user: 'me', srs: 'EPSG:3109')
    `mkdir -p tmp` # for Travis
  end

  def conn
    PG.connect(dbname: ENV['DB'] || GisScraper.config[:dbname], user: ENV['POSTGRES_USER'] || GisScraper.config[:user])
  end

  def clean_tmp_dir
     `rm -rf tmp/*`
  end

  let(:feature_layer) { Layer.new 'http://gps.digimap.gg/arcgis/rest/services/StatesOfJersey/JerseyPlanning/MapServer/11' }
  let(:file_name) { 'Aircraft Noise Zone 1.json' }
  let(:group_layer) { Layer.new 'http://gps.digimap.gg/arcgis/rest/services/JerseyUtilities/JerseyUtilities/MapServer/146' }
  let(:no_layer_id_url) { Layer.new 'no/layer/number/specified/MapServer' }
  let(:not_map_server_url) { Layer.new '"MapServer"/missing/42' }
  let(:feature_layer_with_path) { Layer.new 'http://gps.digimap.gg/arcgis/rest/services/StatesOfJersey/JerseyPlanning/MapServer/11', '~/Desktop' }
  let(:feature_layer_unsafe_characters) { Layer.new 'http://gps.digimap.gg/arcgis/rest/services/StatesOfJersey/JerseyPlanning/MapServer/14' }
  let(:layer_with_sub_group_layers) { Layer.new 'http://gps.digimap.gg/arcgis/rest/services/JerseyUtilities/JerseyUtilities/MapServer/129' }
  let(:annotation_layer) { Layer.new 'http://gps.digimap.gg/arcgis/rest/services/JerseyUtilities/JerseyUtilities/MapServer/8' }
  let(:sub_layer_ids) { [130, 133, 136] }
  dir_names = ['tmp/Jersey Gas/High Pressure', 'tmp/Jersey Gas/Low Pressure', 'tmp/Jersey Gas/Medium Pressure']

  let(:scraper_double) { instance_double 'FeatureScraper' }

  context '#new(url)' do
    it 'raises ArgumentError "URL must end with layer id" with a URL not ending in an integer' do
      expect(->{no_layer_id_url}).to raise_error ArgumentError, 'URL must end with layer id'
    end

    it 'raises ArgumentError "Bad MapServer URL" with a URL not ending "MapServer/<integer>"' do
      expect(->{not_map_server_url}).to raise_error ArgumentError, 'Bad MapServer URL'
    end

    it 'instantiates an instance of the class with a valid MapServer layer url string' do
      expect(feature_layer.class).to eq Layer
    end
  end

  context '#validate_type' do
    it 'raises UnknownLayerType <type> if layer type is not in TYPES' do
      expect(->{feature_layer.send(:validate_type, 'Unknown Layer')}).to raise_error Layer::UnknownLayerType, 'Unknown Layer'
    end
  end

  context '#type' do
    it 'returns the layer type for a feature layer' do
      expect(feature_layer.send :type).to eq 'Feature Layer'
    end

    it 'returns the layer type for a group layer' do
      expect(group_layer.send :type).to eq 'Group Layer'
    end
  end

  context '#sub_layer_ids' do
    it 'returns an empty list for a feature layer (which have no sub layers)' do
      expect(feature_layer.send :sub_layer_ids).to eq []
    end

    it 'returns a list of the sublayer ids for a group layer, if any' do
      expect(layer_with_sub_group_layers.send :sub_layer_ids).to eq sub_layer_ids
    end
  end

  context '#write_json_files' do
    it "writes a feature layer's data to a JSON file to configured path if no path is specified" do
      layer = feature_layer
      begin
        layer.send :write_json_files
        expect(Dir['tmp/*']).to include "tmp/#{file_name}"
      ensure
        clean_tmp_dir
      end
    end

    it "writes a feature layer's data to a JSON file to the path specified" do
      layer = feature_layer_with_path
      begin
        layer.send :write_json_files
        expect(Dir['/Users/me/Desktop/*']).to include "/Users/me/Desktop/#{file_name}"
      ensure
        `rm ~/Desktop/#{Shellwords.escape(file_name)}`
      end
    end

    it 'writes a feature layer whose name contains unsfafe characters e.g. "/"' do
      file_name = 'Mineral_Sand Extraction Site.json'
      layer = feature_layer_unsafe_characters
      begin
        layer.send :write_json_files
        expect(Dir['tmp/*']).to include "tmp/#{file_name}"
      ensure
        clean_tmp_dir
      end
    end
  end

  context '#output_json', :public do
    it 'calls #write_json_files for an annotation layer' do
      layer = annotation_layer
      allow_any_instance_of(Layer).to receive(:json_data) { nil }
      begin
        layer.output_json
        expect(Dir['tmp/*']).to include 'tmp/Annotation6.json'
      ensure
        clean_tmp_dir
      end
    end

    it 'calls #write_json_files for a feature layer' do
      layer = feature_layer
      allow_any_instance_of(Layer).to receive(:json_data) { nil }
      begin
        layer.output_json
        expect(Dir['tmp/*']).to include "tmp/#{file_name}"
      ensure
        clean_tmp_dir
      end
    end

    it 'for a group layer creates sub directories mirroring sub-group structure' do
      allow_any_instance_of(Layer).to receive :write_json_files # stub recursive instances, so nothing is scraped!!
      begin
        layer_with_sub_group_layers.output_json
        expect(Dir['tmp/*/*'].sort).to eq dir_names
      ensure
        clean_tmp_dir
      end
    end

    it 'for a group layer calls #write_json_files for each underlying feature layer' do
      shell_safe_dir_names = dir_names.map { |str| str.gsub(' ', '\ ') }
      allow_any_instance_of(Layer).to receive(:json_data) { {} } # stub recursive instances, so nothing is scraped!!
      begin
        layer_with_sub_group_layers.output_json
        shell_safe_dir_names.all? { |dir| expect(Dir['tmp/**/*.json'].size).to eq 6 } # 6 json files should be written in total
      ensure
        clean_tmp_dir
      end
    end
  end

  context '#output_to_db' do
    it 'raises error OgrMissing if ogr2ogr executable is not found' do
      allow_any_instance_of(Layer).to receive(:ogr2ogr?) { nil }
      expect(->{feature_layer.output_to_db}).to raise_error Layer::OgrMissing
    end

    it 'raises error NoDatabase if cannot connect to db with config options' do
      allow_any_instance_of(Layer).to receive(:db?) { nil }
      expect(->{feature_layer.output_to_db}).to raise_error Layer::NoDatabase
    end

    # it 'writes a single JSON layer file to a PostgresSQL database table with the same name (lowercased)' do
    #   begin
    #     `cp spec/fixtures/test.json tmp`
    #     feature_layer.send(:write_json_files_to_db_tables)
    #     res = conn.exec("SELECT table_name FROM information_schema.tables WHERE table_schema = 'public'")
    #     expect(res[0]['table_name']).to eq 'test'
    #   ensure
    #     conn.exec 'drop schema public cascade;'
    #     conn.exec 'create schema public;'
    #     clean_tmp_dir
    #   end
    # end

    # it 'writes a single JSON layer file to a PostgresSQL database table with the same name (lowercased)' do
    #   begin
    #     `mkdir tmp/dir`
    #     `cp spec/fixtures/test.json tmp/dir`
    #     `cp spec/fixtures/test.json tmp/test1.json`
    #     feature_layer.send(:write_json_files_to_db_tables)
    #     res = conn.exec("SELECT table_name FROM information_schema.tables WHERE table_schema = 'public'")
    #     expect(res.map { |tup| tup['table_name'] }.sort).to eq ['test', 'test1']
    #   ensure
    #     conn.exec 'drop schema public cascade;'
    #     conn.exec 'create schema public;'
    #     clean_tmp_dir
    #   end
    # end
  end

  context '#esri_geom' do
    it 'returns the esri geometry type from a JSON file' do
      expect(feature_layer.send(:esri_geom, 'spec/fixtures/test.json')).to eq 'esriGeometryPoint'
    end
  end

  context '#geom' do
    it 'raises error "Unknown geometry type: <esri geometry>" if the layer has an unknown type' do
      allow_any_instance_of(Layer).to receive(:esri_geom).with('esriGeometryPoint') { 'esriGeometryUnknown' }
      expect(->{feature_layer.send(:geom, 'esriGeometryPoint')}).to raise_error "Unknown geometry type: 'esriGeometryUnknown'"
    end

    it 'returns the esri geometry type from a JSON file' do
      expect(feature_layer.send(:esri_geom, 'spec/fixtures/test.json')).to eq 'esriGeometryPoint'
    end
  end

end
