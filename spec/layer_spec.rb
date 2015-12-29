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

  let(:feature_layer) { Layer.new 'http://gps.digimap.gg/arcgis/rest/services/StatesOfJersey/JerseyMappingOL/MapServer/0' }
  let(:group_layer) { Layer.new 'http://gps.digimap.gg/arcgis/rest/services/JerseyUtilities/JerseyUtilities/MapServer/146' }
  let(:no_layer_id_url) { Layer.new 'no/layer/number/specified/MapServer' }
  let(:not_map_server_url) { Layer.new '"MapServer"/missing/42' }
  let(:feature_layer_with_path) { Layer.new 'http://gps.digimap.gg/arcgis/rest/services/StatesOfJersey/JerseyPlanning/MapServer/11' }
  let(:feature_layer_unsafe_characters) { Layer.new 'http://gps.digimap.gg/arcgis/rest/services/StatesOfJersey/JerseyPlanning/MapServer/14' }
  let(:layer_with_sub_group_layers) { Layer.new 'http://gps.digimap.gg/arcgis/rest/services/JerseyUtilities/JerseyUtilities/MapServer/129' }
  let(:annotation_layer) { Layer.new 'http://gps.digimap.gg/arcgis/rest/services/JerseyUtilities/JerseyUtilities/MapServer/8' }
  sub_layers = [{'id' => 130, 'name' => 'High Pressure'},
                {'id' => 133, 'name' => 'Medium Pressure'},
                {'id' => 136, 'name' =>'Low Pressure'}]

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

  context '#sub_layer_id_names' do
    it 'returns an empty list for a feature layer (which have no sub layers)' do
      expect(feature_layer.send :sub_layer_id_names).to eq []
    end

    it 'returns a list of the sublayer hashes for :id, :name for a group layer, if any' do
      expect(layer_with_sub_group_layers.send :sub_layer_id_names).to eq sub_layers
    end
  end

  context '#write_json_files' do
    it "writes a feature layer's data to a JSON file in the path specified or '.'" do
      file_name = 'Aircraft Noise Zone 1.json'
      layer = feature_layer_with_path
      begin
        layer.send :write_json_files
        expect(`ls tmp`).to include file_name
      ensure
        clean_tmp_dir
      end
    end

    it 'writes a feature layer whose name contains unsfafe characters e.g. "/"' do
      file_name = 'Mineral_Sand Extraction Site.json'
      layer = feature_layer_unsafe_characters
      begin
        layer.send :write_json_files
        expect(`ls tmp`).to include file_name
      ensure
        clean_tmp_dir
      end
    end
  end

  context '#sub_layer(id, path)' do
    it 'returns the a Layer object for the given the sub layer id' do
      expect(layer_with_sub_group_layers.send(:sub_layer, 130, 'tmp').class). to eq Layer
    end
  end

  context '#output_json', :public do
    it 'calls #write_json_files for an annotation layer' do
      layer = annotation_layer
      allow_any_instance_of(Layer).to receive(:json_data) { nil }
      begin
        layer.output_json
        expect(`ls tmp`).to include 'Annotation6.json'
      ensure
        clean_tmp_dir
      end
    end

    it 'calls #write_json_files for a feature layer' do
      layer = feature_layer
      allow_any_instance_of(Layer).to receive(:json_data) { nil }
      begin
        layer.output_json
        expect(`ls tmp`).to include 'Gazetteer.json'
      ensure
        clean_tmp_dir
      end
    end

    it 'for a group layer creates sub directories mirroring sub-group structure' do
      dir_names = ['High Pressure', 'Medium Pressure', 'Low Pressure']
      allow_any_instance_of(Layer).to receive :write_json_files # stub recursive instances, so nothing is scraped!!
      begin
        layer_with_sub_group_layers.output_json
        dir_names.all? { |dir| expect(`ls tmp`).to include dir }
      ensure
        clean_tmp_dir
      end
    end

    it 'for a group layer calls #write_json_files for each underlying feature layer' do
      dir_names = ['High Pressure', 'Medium Pressure', 'Low Pressure']
      shell_safe_dir_names = dir_names.map { |str| str.gsub(' ', '\ ') }
      allow_any_instance_of(Layer).to receive(:json_data) { {} } # stub recursive instances, so nothing is scraped!!
      begin
        layer_with_sub_group_layers.output_json
        shell_safe_dir_names.all? { |dir| expect(`ls tmp/#{dir} | wc -l`.chomp.to_i).to eq 2 } # 2 json files should be written to each dir
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

    it 'writes a single JSON layer file to a PostgresSQL database table with the same name (lowercased)' do
      begin
        `cp spec/fixtures/test.json tmp`
        feature_layer.send(:write_json_files_to_db_tables)
        res = conn.exec("SELECT table_name FROM information_schema.tables WHERE table_schema = 'public'")
        expect(res[0]['table_name']).to eq 'test'
      ensure
        conn.exec 'drop schema public cascade;'
        conn.exec 'create schema public;'
        clean_tmp_dir
      end
    end

    it 'writes a single JSON layer file to a PostgresSQL database table with the same name (lowercased)' do
      begin
        `mkdir tmp/dir`
        `cp spec/fixtures/test.json tmp/dir`
        `cp spec/fixtures/test.json tmp/test1.json`
        feature_layer.send(:write_json_files_to_db_tables)
        res = conn.exec("SELECT table_name FROM information_schema.tables WHERE table_schema = 'public'")
        expect(res.map { |tup| tup['table_name'] }.sort).to eq ['test', 'test1']
      ensure
        conn.exec 'drop schema public cascade;'
        conn.exec 'create schema public;'
        clean_tmp_dir
      end
    end
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
