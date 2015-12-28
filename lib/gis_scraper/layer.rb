require 'fileutils'

class Layer

  class JSONParser < Mechanize::File
    attr_reader :json

    def initialize(uri=nil, response=nil, body=nil, code=nil)
      super(uri, response, body, code)
      @json = JSON.parse(body)
    end
  end

  class UnknownLayerType < StandardError; end

  class OgrMissing < StandardError; end

  attr_reader :type, :id, :name

  TYPES = ['Group Layer',
           'Feature Layer',
           'Annotation Layer',
           'Annotation SubLayer']
  QUERYABLE = ['Feature Layer', 'Annotation Layer']

  def initialize(url, output_path = nil)
    @url = url
    @output_path = output_path || config_path
    @ms_url = ms_url # map server url ending '../MapServer'
    @id = id
    @agent = Mechanize.new
    @agent.pluggable_parser['text/plain'] = JSONParser
    validate_url
    @page_json = page_json
    @type = type
    @name = name
  end

  def output_json
    QUERYABLE.any? { |l| @type == l } ? write_json_files : process_sub_layers
  end

  def output_to_db
    raise OgrMissing.new, 'ogr2ogr missing, is GDAL installed?' unless ogr2ogr?
    @output_path = 'tmp' # write all files to Gem's tmp dir
    output_json
    write_json_files_to_db_tables
  end

  private

  def config_path
    File.expand_path GisScraper.config[:output_path]
  end

  def ogr2ogr?
    `ogr2ogr --version` rescue nil
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

  def sub_layer_id_names
    @page_json['subLayers'] || []
  end

  def json_data(url)
    FeatureScraper.new(url).json_data
  end

  def write_json_files
    File.write "#{@output_path}/#{@name}.json", json_data("#{@ms_url}/#{@id}")
  end

  def write_json_files_to_db_tables
    `ogr2ogr -f "PostgreSQL" PG:"dbname=postgres user=me" "tmp/test.json" -nln test -a_srs EPSG:3109 -nlt POINT`
  end

  def process_sub_layers
    sub_layer_id_names.each do |hash|
      name, id = hash['name'], hash['id']
      path = "#{@output_path}/#{name}"
      recurse_json sub_layer(id, path), path
    end
  end

  def recurse_json(layer, dir)
    FileUtils.mkdir dir
    layer.output_json
  end

  def sub_layer(id, path)
    Layer.new "#{@ms_url}/#{id}", path
  end

  def replace_forwardslashes_with_underscores(string)
    string.gsub /\//, '_'
  end

end
