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

  attr_reader :type

  GL = 'Group Layer'

  def initialize(url, path = '.')
    @url, @path = url, File.expand_path(path)
    @ms_url = ms_url # map server url ending '../MapServer'
    @id = id
    @agent = Mechanize.new
    @agent.pluggable_parser['text/plain'] = JSONParser
    validate_url
    @page_json = page_json
    @type = type
    @layer_ids = layer_ids
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
    @page_json['type']
  end

  def sub_layer_id_names
    @page_json['subLayers']
  end

  def layer_ids
    @type == 'Feature Layer' ? [@id] : group_layer_ids
  end

  def group_layer_ids
    @page_json['subLayers'].map { |layer| layer['id'] }
  end

  def layers_data_json_list
    @layer_ids.map { |id| FeatureScraper.new("#{@ms_url}/#{id}").json_data }
  end

  def layer_name_list
    @layer_ids.map { |id| FeatureScraper.new("#{@ms_url}/#{id}").name }
  end

  def write_feature_files
    layer_name_list.zip(layers_data_json_list).each do |arr|
      File.write(@path + "/#{arr.first}.json", arr.last)
    end
  end

  def write
    type == GL ? process_sub_layers : write_feature_files
  end

  def process_sub_layers
    sub_layer_id_names.each do |h|
      sub_path = @path + '/' + h['name']
      layer = sub_layer(h['id'], sub_path)
      layer.type == GL ? recurse(layer, sub_path) : write_feature_files
    end
  end

  def recurse(layer, dir)
    FileUtils.mkdir dir
    layer.write
  end

  def sub_layer(id, path)
    Layer.new "#{@ms_url}/#{id}", path
  end

end
