require 'fileutils'
require 'tmpdir'
require 'shellwords'

# an ArcGIS layer
class Layer
  class UnknownLayerType < StandardError; end
  class NoDatabase < StandardError; end
  class OgrMissing < StandardError; end

  attr_reader :type

  TABLES = "SELECT table_name FROM information_schema.tables\
   WHERE table_schema = 'public'".freeze

  TYPE = ['Group Layer', 'Feature Layer', 'Annotation Layer',
          'Annotation SubLayer'].freeze

  CONN = [:host, :port, :dbname, :user, :password].freeze

  GEOM_TYPES = { 'esriGeometryPoint' => 'POINT',
                 'esriGeometryMultipoint' => 'MULTIPOINT',
                 'esriGeometryLine' => 'LINESTRING',
                 'esriGeometryPolyline' => 'MULTILINESTRING',
                 'esriGeometryPolygon' => 'MULTIPOLYGON' }.freeze

  MSURL = 'MapServer'.freeze
  OGR = 'ogr2ogr -overwrite -f "PostgreSQL" PG:'.freeze

  def initialize(url, path = nil)
    @conn_hash = CONN.zip(CONN.map { |key| GisScraper.config[key] }).to_h
    @url = url
    @output_path = output_path(path) || config_path
    @id = id
    @mapserver_url = mapserver_url # mapserver url ends '../MapServer'
    @agent = Mechanize.new
    @agent.pluggable_parser['text/plain'] = GisScraper::JSONParser
    validate_url
    @page_json = page_json
    @type = type
    @name = name
    @sub_layer_ids = sub_layer_ids
    @geo = geo
  end

  def output_json
    output(:json)
  end

  def output_to_db
    raise OgrMissing.new, 'ogr2ogr missing, is GDAL installed?' unless ogr2ogr?
    raise NoDatabase.new, "No db connection: #{@conn_hash.inspect}" unless conn
    output(:db)
  end

  private

  def output(format) # recurses sub-layers, if any (none for Annotation layers)
    (@type == 'Feature Layer' && @geo) ? method(format) : do_sub_layers(format)
  end

  def method(format)
    return write_json if format == :json
    return write_to_db if format == :db
    raise "Unknown output format: #{format}"
  end

  def output_path(path)
    File.expand_path(path) if path
  end

  def conn
    PG.connect(@conn_hash) rescue nil
  end

  def ogr2ogr?
    `ogr2ogr --version` rescue nil
  end

  def config_path
    File.expand_path GisScraper.config[:output_path]
  end

  def mapserver_url
    @url.split('/')[0..-2].join('/')
  end

  def id
    @url.split('/').last
  end

  def validate_url
    raise ArgumentError, 'URL must end with layer id' if @id.to_i.to_s != @id
    raise ArgumentError, 'Bad MapServer URL' if @mapserver_url[-9..-1] != MSURL
  end

  def page_json
    @agent.get(@url + '?f=pjson').json
  end

  def type
    validate_type @page_json['type']
  end

  def name
    replace_forwardslashes_with_underscores @page_json['name']
  end

  def validate_type(type)
    raise UnknownLayerType, type unless TYPE.any? { |t| t == type }
    type
  end

  def sub_layer_ids
    @page_json['subLayers'].map { |hash| hash['id'] } || []
  end

  def json_data
    FeatureScraper.new("#{@mapserver_url}/#{@id}").json_data
  end

  def write_json
    IO.write json_path, json_data
  end

  def json_path
    "#{@output_path}/#{@name}.json"
  end

  def write_to_db
    @output_path = Dir.mktmpdir('gis_scraper') # prefix for identification
    begin
      write_json
      `#{OGR}"#{conn_str}" "#{json_path}" -nln #{table} #{srs} -nlt #{geom}`
    ensure
      FileUtils.remove_entry @output_path
    end
  end

  def geom
    GEOM_TYPES[@geo] || raise("Unknown geom: '#{@geo}' for layer #{@name}")
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
    host, port, db, user, pwd = *@conn_hash.values
    "host=#{host} port=#{port} dbname=#{db} user=#{user} password=#{pwd}"
  end

  def do_sub_layers(format)
    FileUtils.mkdir File.join(@output_path, @name) if format == :json
    path = @output_path << "/#{@name}"
    @sub_layer_ids.each { |n| sub_layer(n, path).send(:output, format) }
  end

  def sub_layer(id, path)
    Layer.new("#{@mapserver_url}/#{id}", path)
  end

  def replace_forwardslashes_with_underscores(string)
    string.tr('/', '_')
  end
end
