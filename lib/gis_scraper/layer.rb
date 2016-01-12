require 'fileutils'
require 'shellwords'

class Layer

  class JSONParser < Mechanize::File
    attr_reader :json

    def initialize(uri=nil, response=nil, body=nil, code=nil)
      super(uri, response, body, code)
      @json = JSON.parse(body)
    end
  end

  class UnknownLayerType < StandardError; end
  class NoDatabase < StandardError; end
  class OgrMissing < StandardError; end

  attr_reader :type

  TYPES = ['Group Layer',
           'Feature Layer',
           'Annotation Layer',
           'Annotation SubLayer']
  QUERYABLE = ['Feature Layer', 'Annotation Layer']

  CONN = [:host, :port, :dbname, :user, :password] # PG connection options

  GEOM_TYPES = {'esriGeometryPoint' => 'POINT',
                'esriGeometryMultipoint' => 'MULTIPOINT',
                'esriGeometryLine' => 'LINESTRING',
                'esriGeometryPolyline' => 'MULTILINESTRING',
                'esriGeometryPolygon' => 'MULTIPOLYGON'}


  OGR2OGR = 'ogr2ogr -f "PostgreSQL" PG:'

  def initialize(url, path = nil)
    @conn_hash = CONN.zip(CONN.map { |key| GisScraper.config[key] }).to_h
    @url = url
    @output_path = output_path(path) || config_path
    @ms_url = ms_url # map server url ending '../MapServer'
    @id = id
    @agent = Mechanize.new
    @agent.pluggable_parser['text/plain'] = JSONParser
    validate_url
    @page_json = page_json
    @type = type
    @name = name
    @sub_layer_ids = sub_layer_ids
  end

  def output_json
    QUERYABLE.any? { |l| @type == l } ? write_json : do_sub_layers(__method__)
  end

  def output_to_db
    raise OgrMissing.new, 'ogr2ogr missing, is GDAL installed?' if !ogr2ogr?
    raise NoDatabase.new, "No db connection: #{@conn_hash.inspect}" if !db?
    @output_path = 'tmp' # write all files to the Gem's tmp dir
    QUERYABLE.any? { |l| @type == l } ? write_to_db : do_sub_layers(__method__)
  end

  private

  def output_path(path)
    File.expand_path(path) if path
  end

  def db?
    PG.connect(@conn_hash) rescue nil
  end

  def ogr2ogr?
    `ogr2ogr --version` rescue nil
  end

  def config_path
    File.expand_path GisScraper.config[:output_path]
  end

  def ms_url
    @url.split('/')[0..-2].join('/')
  end

  def id
    @url.split('/').last
  end

  def validate_url
    raise ArgumentError, 'URL must end with layer id' if  @id.to_i.to_s != @id
    raise ArgumentError, 'Bad MapServer URL' if @ms_url[-9..-1] != 'MapServer'
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
    raise UnknownLayerType, type unless (TYPES.any? { |t| t == type })
    type
  end

  def sub_layer_ids
    @page_json['subLayers'].map { |hash| hash['id'] } || []
  end

  def json_data(url)
    FeatureScraper.new(url).json_data
  end

  def write_json
    File.write "#{@output_path}/#{@name}.json", json_data("#{@ms_url}/#{@id}")
  end

  def write_to_db
    write_json
    `#{OGR2OGR}"#{conn}" "#{file_path}" -nln #{table} #{srs} -nlt #{geom}`
  end

  def file_path
    @output_path << '/' << @name << '.json'
  end

  def geom
    esri = esri_geom
    GEOM_TYPES[esri] || raise("Unknown geometry: '#{esri}' for layer #{@name}")
  end

  def esri_geom
    @page_json['geometryType']
  end

  def srs
    return '' unless GisScraper.config[:srs]
    "-a_srs #{GisScraper.config[:srs]}" || ''
  end

  def table
    Shellwords.escape @name.downcase
  end

  def conn
    host, port, db, user, pwd = *@conn_hash.values
    "host=#{host} port=#{port} dbname=#{db} user=#{user} password=#{pwd}"
  end

  def do_sub_layers(method) # recurses
    FileUtils.mkdir File.join(@output_path, @name) if method == :output_json
    path = @output_path << "/#{@name}"
    @sub_layer_ids.each { |n| Layer.new("#{@ms_url}/#{n}", path).send(method) }
  end

  def replace_forwardslashes_with_underscores(string)
    string.gsub /\//, '_'
  end

end
