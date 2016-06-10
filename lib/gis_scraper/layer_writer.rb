require 'fileutils'
require 'tmpdir'
require 'shellwords'

# tool to write ArcGIS layer(s) to json or database output
class LayerWriter
  attr_reader :type

  TABLES = "SELECT table_name FROM information_schema.tables\
   WHERE table_schema = 'public'".freeze
  TYPES = ['Group ', 'Feature ', 'Annotation ', 'Annotation Sub'].freeze
  CONN = [:host, :port, :dbname, :user, :password].freeze
  GEOM_TYPES = { 'esriGeometryPoint' => 'POINT',
                 'esriGeometryMultipoint' => 'MULTIPOINT',
                 'esriGeometryLine' => 'LINESTRING',
                 'esriGeometryPolyline' => 'MULTILINESTRING',
                 'esriGeometryPolygon' => 'MULTIPOLYGON' }.freeze
  OGR = 'ogr2ogr -overwrite -f "PostgreSQL" PG:'.freeze

  def initialize(url, path = nil)
    @conn = CONN.zip(CONN.map { |key| GisScraper.config[key] }).to_h
    @url = url
    @output_path = output_path(path) || config_path
    @id = id
    @service_url = service_url
    @layer = layer
    @page_json = @layer.json
    @type = type
    @name = name
  end

  def output_json
    output(:json)
  end

  def output_to_db
    raise 'ogr2ogr executable missing, is GDAL installed?' unless ogr2ogr?
    output(:db)
  end

  private

  def output(format) # recurses sub-layers, if any (none for Annotation layers)
    @type == 'Feature Layer' ? method(format) : do_sub_layers(format)
  end

  def method(format)
    format == :db ? write_to_db : write_json
  end

  def output_path(path)
    File.expand_path(path) if path
  end

  def conn
    PG.connect(@conn)
  end

  def ogr2ogr?
    `ogr2ogr --version`
  rescue Errno::ENOENT
    nil
  end

  def config_path
    File.expand_path GisScraper.config[:output_path]
  end

  def service_url
    @url.split('/')[0..-2].join('/')
  end

  def id
    @url.split('/').last
  end

  def layer
    ArcREST::Layer.new @url
  end

  def type
    validate_layer @page_json['type']
  end

  def validate_layer(typ)
    raise "Bad Layer type: #{typ}" unless TYPES.any? { |t| "#{t}Layer" == typ }
    typ
  end

  def name
    @page_json['name'].tr('/', '_') # make Postgres-safe
  end

  def sub_layer_ids
    @page_json['subLayers'].map { |hash| hash['id'] } || []
  end

  def json_data
    FeatureScraper.new("#{@service_url}/#{@id}").json_data
  end

  def write_json
    IO.write json_path, json_data
  end

  def json_path
    "#{@output_path}/#{@name}.json"
  end

  def write_to_db
    @output_path = Dir.mktmpdir('gis_scraper') # prefix for identification
    write_json
    `#{OGR}"#{conn_str}" "#{json_path}" -nln #{table} #{srs} -nlt #{pg_geom}`
  ensure
    FileUtils.remove_entry @output_path
  end

  def pg_geom
    GEOM_TYPES[geo] || raise("Unknown geom: '#{geo}' for layer #{@name}")
  end

  def geo
    @page_json['geometryType']
  end

  def srs
    return '' unless GisScraper.config[:srs]
    "-a_srs #{GisScraper.config[:srs]}" || ''
  end

  def tables # list of current db table names
    conn.exec(TABLES).map { |tup| tup['table_name'] }
  end

  def table
    table_name << table_suffix
  end

  def table_name
    Shellwords.escape(@name.downcase.tr(' ', '_')).prepend('_')
  end

  def table_suffix
    tables.any? { |t| t == table_name } ? '_' : ''
  end

  def conn_str
    host, port, db, user, pwd = *@conn.values
    "host=#{host} port=#{port} dbname=#{db} user=#{user} password=#{pwd}"
  end

  def do_sub_layers(format)
    FileUtils.mkdir File.join(@output_path, @name) if format == :json
    path = @output_path << "/#{@name}"
    sub_layer_ids.each { |n| sub_layer(n, path).send(:output, format) }
  end

  def sub_layer(id, path)
    self.class.new("#{@service_url}/#{id}", path)
  end
end
