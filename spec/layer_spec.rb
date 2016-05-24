require 'shellwords'

describe Layer do
  DIGIMAP = 'http://gps.digimap.gg/arcgis/rest/services'.freeze

  user = ENV['POSTGRES_USER'] || `whoami`.chomp

  path = ENV['HOME']

  before do
    GisScraper.configure(output_path: Dir.tmpdir, srs: 'EPSG:3109', user: user)
  end

  def conn
    PG.connect(host: 'localhost',
               dbname: ENV['DB'] || GisScraper.config[:dbname],
               user: ENV['POSTGRES_USER'] || GisScraper.config[:user])
  end

  let(:tmp) { Dir.tmpdir }

  def clean_tmp_dir
    `rm -rf #{tmp}/*`
  end

  let(:feature_layer) { Layer.new 'http://gps.digimap.gg/arcgis/rest/services/StatesOfJersey/JerseyPlanning/MapServer/11' }
  let(:file_name) { 'Aircraft Noise Zone 1.json' }
  let(:group_layer) { Layer.new 'http://gps.digimap.gg/arcgis/rest/services/JerseyUtilities/JerseyUtilities/MapServer/146' }
  let(:no_layer_id_url) { Layer.new 'no/layer/number/specified/MapServer' }
  let(:not_map_server_url) { Layer.new '"MapServer"/missing/42' }
  let(:feature_layer_with_path) { Layer.new 'http://gps.digimap.gg/arcgis/rest/services/StatesOfJersey/JerseyPlanning/MapServer/11', path }
  let(:feature_layer_unsafe_characters) { Layer.new 'http://gps.digimap.gg/arcgis/rest/services/StatesOfJersey/JerseyPlanning/MapServer/14' }
  let(:layer_with_sub_group_layers) { Layer.new 'http://gps.digimap.gg/arcgis/rest/services/JerseyUtilities/JerseyUtilities/MapServer/129' }
  let(:group_layer_with_duplicate_layer_names) { Layer.new "#{DIGIMAP}/JerseyUtilities/JerseyUtilities/MapServer/117" }
  let(:annotation_layer) { Layer.new 'http://gps.digimap.gg/arcgis/rest/services/JerseyUtilities/JerseyUtilities/MapServer/8' }
  let(:layer_with_no_geometry) { Layer.new 'http://gps.digimap.gg/arcgis/rest/services/JerseyUtilities/JerseyUtilities/MapServer/6' }
  let(:sub_layer_ids) { [130, 133, 136] }
  let(:ds) { ["#{tmp}/Jersey Gas/High Pressure", "#{tmp}/Jersey Gas/Low Pressure", "#{tmp}/Jersey Gas/Medium Pressure"] }
  let(:tables) { ["_gas_high_pressure_main", "_gas_low_pressure_main", "_gas_medium_pressure_main", "_high_pressure_asset", "_low_pressure_asset", "_medium_pressure_asset"] }

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

  context '#write_json' do
    it "writes a feature layer's data to a JSON file to configured path if no path is specified" do
      layer = feature_layer
      begin
        layer.send :write_json
        expect(Dir["#{Dir.tmpdir}/*"]).to include "#{tmp}/#{file_name}"
      ensure
        clean_tmp_dir
      end
    end

    it "writes a feature layer's data to a JSON file to the path specified" do
      layer = feature_layer_with_path
      begin
        layer.send :write_json
        expect(Dir["#{path}/*"]).to include "#{path}/#{file_name}"
      ensure
        `rm #{path}/#{Shellwords.escape(file_name)}`
      end
    end

    it 'writes a feature layer whose name contains unsfafe characters e.g. "/"' do
      file_name = 'Mineral_Sand Extraction Site.json'
      layer = feature_layer_unsafe_characters
      begin
        layer.send :write_json
        expect(Dir["#{Dir.tmpdir}/*"]).to include "#{tmp}/#{file_name}"
      ensure
        clean_tmp_dir
      end
    end
  end

  context '#output_json', :public do
    it 'does not call #write_json for an annotation layer' do
      layer = annotation_layer
      allow_any_instance_of(Layer).to receive(:json_data) { nil }
      begin
        layer.output_json
        expect(layer).not_to receive(:write_json)
      ensure
        clean_tmp_dir # in case it fails
      end
    end

    it 'does not call #write_json for a layer with no geometryType' do
      layer = layer_with_no_geometry
      allow_any_instance_of(Layer).to receive(:json_data) { nil }
      begin
        layer.output_json
        expect(layer).not_to receive(:write_json)
      ensure
        clean_tmp_dir # in case it fails
      end
    end

    it 'calls #write_json for a feature layer' do
      layer = feature_layer
      allow_any_instance_of(Layer).to receive(:json_data) { nil }
      begin
        layer.output_json
        expect(Dir["#{Dir.tmpdir}/*"]).to include "#{tmp}/#{file_name}"
      ensure
        clean_tmp_dir
      end
    end

    context 'for a group layer' do
      it 'creates sub directories mirroring sub-group structure' do
        allow_any_instance_of(Layer).to receive :write_json_files
        begin
          layer_with_sub_group_layers.output_json
          expect(ds.all? { |d| Dir["#{Dir.tmpdir}/*/*"].include? d }).to eq true
        ensure
          clean_tmp_dir
        end
      end

      it 'calls #write_json_files for each underlying feature layer' do
        safe_dirs = ds.map { |str| str.gsub(' ', '\ ') }
        allow_any_instance_of(Layer).to receive(:json_data) { {} }
        begin
          layer_with_sub_group_layers.output_json
          safe_dirs.all? { expect(Dir["#{Dir.tmpdir}/**/*.json"].size).to eq 6 }
        ensure
          clean_tmp_dir
        end
      end
    end
  end

  context '#output_to_db' do
    it 'raises error OgrMissing if ogr2ogr executable is not found' do
      allow_any_instance_of(Layer).to receive(:ogr2ogr?) { nil }
      expect(->{ feature_layer.output_to_db }).to raise_error Layer::OgrMissing
    end

    it 'raises error NoDatabase if cannot connect to db with config options' do
      allow_any_instance_of(Layer).to receive(:conn) { nil }
      expect(->{ feature_layer.output_to_db }).to raise_error Layer::NoDatabase
    end

    it 'writes a single JSON layer file to a PostgresSQL database table with the same name (lowercased)' do
      begin
        feature_layer.output_to_db
        res = conn.exec("SELECT table_name FROM information_schema.tables WHERE table_schema = 'public'")
        expect(res[0]['table_name']).to eq '_aircraft_noise_zone_1'
      ensure
        conn.exec 'drop schema public cascade;'
        conn.exec 'create schema public;'
        clean_tmp_dir
      end
    end

    it 'writes a set of JSON layer files to PostgresSQL database tables for a group layer' do
      begin
        layer_with_sub_group_layers.output_to_db
        res = conn.exec("SELECT table_name FROM information_schema.tables WHERE table_schema = 'public'")
        expect(res.map { |tup| tup['table_name'] }.sort).to eq tables
      ensure
        conn.exec 'drop schema public cascade;'
        conn.exec 'create schema public;'
        clean_tmp_dir
      end
    end

    it 'adds a suffix "_" to the table name if it is non-unique' do
      conn.exec('CREATE TABLE _aircraft_noise_zone_1 (d date);')
      begin
        feature_layer.output_to_db
        res = conn.exec("SELECT table_name FROM information_schema.tables WHERE table_schema = 'public'")
        expect(res.map { |tup| tup['table_name'] }.sort).to eq %w(_aircraft_noise_zone_1 _aircraft_noise_zone_1_)
      ensure
        conn.exec 'drop schema public cascade;'
        conn.exec 'create schema public;'
        clean_tmp_dir
      end
    end
  end

  context '#geo' do
    it 'returns the esri geometry type from a JSON file' do
      expect(feature_layer.send(:geo)).to eq 'esriGeometryPolygon'
    end
  end

  context '#geom' do
    it 'returns the PostGIS geometry type from a JSON file' do
      expect(feature_layer.send(:geom)).to eq 'MULTIPOLYGON'
    end

    it 'raises "Unknown geom type: <esri geometry>" for an unknown type' do
      layer = feature_layer
      layer.instance_variable_set(:@geo, 'esriGeometryUnknown')
      e = "Unknown geom: 'esriGeometryUnknown' for layer Aircraft Noise Zone 1"
      expect(-> { layer.send(:geom) }).to raise_error e
    end
  end
end
