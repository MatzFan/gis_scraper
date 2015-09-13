require 'mechanize'
require 'fileutils'

require_relative 'feature_scraper'

class Layer

  class JSONParser < Mechanize::File
    attr_reader :json

    def initialize(uri=nil, response=nil, body=nil, code=nil)
      super(uri, response, body, code)
      @json = JSON.parse(body)
    end
  end

  class UnknownLayerType < StandardError; end

  attr_reader :type, :id, :name

  TYPES = ['Group Layer',
           'Feature Layer',
           'Annotation Layer',
           'Annotation SubLayer']

  def initialize(url, path = '.')
    @url, @path = url, File.expand_path(path)
    @ms_url = ms_url # map server url ending '../MapServer'
    @id = id
    @agent = Mechanize.new
    @agent.pluggable_parser['text/plain'] = JSONParser
    validate_url
    @page_json = page_json
    @type = type
    @name = name
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
    File.write "#{@path}/#{@name}.json", json_data("#{@ms_url}/#{@id}")
  end

  def write
    @type == 'Feature Layer' ? write_json_files : process_sub_layers
  end

  def process_sub_layers
    sub_layer_id_names.each do |hash|
      name, id = hash['name'], hash['id']
      path = "#{@path}/#{name}"
      recurse sub_layer(id, path), path
    end
  end

  def recurse(layer, dir)
    FileUtils.mkdir dir
    layer.write
  end

  def sub_layer(id, path)
    Layer.new "#{@ms_url}/#{id}", path
  end

  private

  def replace_forwardslashes_with_underscores(string)
    string.gsub /\//, '_'
  end

end
