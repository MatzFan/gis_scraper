describe LayerWriter do
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

  let(:gazetteer) { LayerWriter.new 'http://gis.digimap.je/ArcGIS/rest/services/Gazetteer/MapServer/0' }
  let(:feature_layer) { LayerWriter.new 'http://gps.digimap.gg/arcgis/rest/services/StatesOfJersey/JerseyPlanning/MapServer/11' }
  let(:file_name) { 'Aircraft Noise Zone 1.json' }
  let(:group_layer) { LayerWriter.new 'http://gps.digimap.gg/arcgis/rest/services/JerseyUtilities/JerseyUtilities/MapServer/146' }
  let(:no_layer_id_url) { LayerWriter.new 'no/layer/number/specified/MapServer' }
  let(:not_map_server_url) { LayerWriter.new '"MapServer"/missing/42' }
  let(:feature_layer_with_path) { LayerWriter.new 'http://gps.digimap.gg/arcgis/rest/services/StatesOfJersey/JerseyPlanning/MapServer/11', path }
  let(:feature_layer_unsafe_characters) { LayerWriter.new 'http://gps.digimap.gg/arcgis/rest/services/StatesOfJersey/JerseyPlanning/MapServer/14' }
  let(:layer_with_sub_group_layers) { LayerWriter.new 'http://gps.digimap.gg/arcgis/rest/services/JerseyUtilities/JerseyUtilities/MapServer/129' }
  let(:group_layer_with_duplicate_layer_names) { LayerWriter.new "#{DIGIMAP}/JerseyUtilities/JerseyUtilities/MapServer/117" }
  let(:annotation_layer) { LayerWriter.new 'http://gps.digimap.gg/arcgis/rest/services/JerseyUtilities/JerseyUtilities/MapServer/8' }
  let(:layer_with_no_geometry) { LayerWriter.new 'http://gps.digimap.gg/arcgis/rest/services/JerseyUtilities/JerseyUtilities/MapServer/6' }
  let(:sub_layer_ids) { [130, 133, 136] }
  let(:ds) { ["#{tmp}/Jersey Gas/High Pressure", "#{tmp}/Jersey Gas/Low Pressure", "#{tmp}/Jersey Gas/Medium Pressure"] }
  let(:tables) { ["_gas_high_pressure_main", "_gas_low_pressure_main", "_gas_medium_pressure_main", "_high_pressure_asset", "_low_pressure_asset", "_medium_pressure_asset"] }

  let(:scraper_double) { instance_double 'FeatureScraper' }

  context '#new(url)' do
    it 'returns an instance of the class with a layer url string' do
      expect(feature_layer.class).to eq described_class
    end
  end

  context '#validate_type' do
    it 'raises "Bad Layer type <layer_type>" if layer type is not in TYPES' do
      lamb = -> { feature_layer.send(:validate_layer, 'Unknown Layer') }
      expect(lamb).to raise_error 'Bad Layer type: Unknown Layer'
    end
  end

  context '#type' do
    it 'returns the layer type for a feature layer' do
      expect(feature_layer.send(:type)).to eq 'Feature Layer'
    end

    it 'returns the layer type for a group layer' do
      expect(group_layer.send(:type)).to eq 'Group Layer'
    end
  end

  context '#sub_layer_ids' do
    it 'returns an empty list for a feature layer (which have no sub layers)' do
      expect(feature_layer.send(:sub_layer_ids)).to eq []
    end

    it 'returns a list of the sublayer ids for a group layer, if any' do
      expect(layer_with_sub_group_layers.send(:sub_layer_ids)).to eq sub_layer_ids
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
      allow_any_instance_of(LayerWriter).to receive(:json_data) { nil }
      begin
        layer.output_json
        expect(layer).not_to receive(:write_json)
      ensure
        clean_tmp_dir # in case it fails
      end
    end

    it 'does not call #write_json for a layer with no geometryType' do
      layer = layer_with_no_geometry
      allow_any_instance_of(LayerWriter).to receive(:json_data) { nil }
      begin
        layer.output_json
        expect(layer).not_to receive(:write_json)
      ensure
        clean_tmp_dir # in case it fails
      end
    end

    it 'calls #write_json for a feature layer' do
      layer = feature_layer
      allow_any_instance_of(LayerWriter).to receive(:json_data) { nil }
      begin
        layer.output_json
        expect(Dir["#{Dir.tmpdir}/*"]).to include "#{tmp}/#{file_name}"
      ensure
        clean_tmp_dir
      end
    end

    context 'for a group layer' do
      it 'creates sub directories mirroring sub-group structure' do
        allow_any_instance_of(LayerWriter).to receive :write_json_files
        begin
          layer_with_sub_group_layers.output_json
          expect(ds.all? { |d| Dir["#{Dir.tmpdir}/*/*"].include? d }).to eq true
        ensure
          clean_tmp_dir
        end
      end

      it 'calls #write_json_files for each underlying feature layer' do
        safe_dirs = ds.map { |str| str.gsub(' ', '\ ') }
        allow_any_instance_of(LayerWriter).to receive(:json_data) { {} }
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
    it 'raises error if ogr2ogr executable is not found' do
      allow_any_instance_of(LayerWriter).to receive(:ogr2ogr?) { nil }
      lambda = -> { feature_layer.output_to_db }
      expect(lambda).to raise_error 'ogr2ogr executable missing, is GDAL installed?'
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

  context '#pg_geom' do
    it 'returns the PostGIS geometry type from a JSON file' do
      expect(feature_layer.send(:pg_geom)).to eq 'MULTIPOLYGON'
    end

    it 'raises "Unknown geom type: <esri geometry>" for an unknown type' do
      layer = feature_layer
      allow(layer).to receive(:geo) { 'esriGeometryUnknown' }
      e = "Unknown geom: 'esriGeometryUnknown' for layer Aircraft Noise Zone 1"
      expect(-> { layer.send(:pg_geom) }).to raise_error e
    end
  end
end
