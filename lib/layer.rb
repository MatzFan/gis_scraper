require 'mechanize'
require 'fileutils'

require_relative 'feature_scraper'

class Layer

  attr_reader :type

  class JSONParser < Mechanize::File
    attr_reader :json

    def initialize(uri=nil, response=nil, body=nil, code=nil)
      super(uri, response, body, code)
      @json = JSON.parse(body)
    end
  end

  def initialize(url, path = '.')
    @url, @path = url, File.expand_path(path)
    @s_url = s_url # map server url ending '../MapServer'
    @id = id
    @agent = Mechanize.new
    @agent.pluggable_parser['text/plain'] = JSONParser
    validate_url
    @page_json = page_json
    @type = type
    @sub_layers = sub_layers
    @layer_ids = layer_ids
  end

  def s_url
    @url.split('/')[0..-2].join('/')
  end

  def id
    @url.split('/').last
  end

  def validate_url
    raise ArgumentError, "URL must end with layer id" if  @id.to_i.to_s != @id
    raise ArgumentError, 'Not a MapServer URL' if @s_url[-9..-1] != 'MapServer'
  end

  def page_json
    @agent.get(@url + '?f=pjson').json
  end

  def type
    @page_json['type']
  end

  def sub_layers
    @page_json['subLayers']
  end

  def layer_ids
    @type == 'Feature Layer' ? [@id] : group_layer_ids
  end

  def group_layer_ids
    @page_json['subLayers'].map { |layer| layer['id'] }
  end

  def layers_data_json_list
    @layer_ids.map { |id| FeatureScraper.new("#{@s_url}/#{id}").json_data }
  end

  def layer_name_list
    @layer_ids.map { |id| FeatureScraper.new("#{@s_url}/#{id}").name }
  end

  def write_feature_files
    layer_name_list.zip(layers_data_json_list).each do |arr|
      File.write(@path + "/#{arr.first}.json", arr.last)
    end
  end

  def write
    sub_layers.each do |layer|
      if sub_layer_type(layer['id']) == 'Group Layer'
        # FileUtils.mkdir "#{@path}/#{layer['name']}"
        recurse layer
      end
    end
  end

  def recurse(layer)
    FileUtils.mkdir "#{@path}/#{layer['name']}"
  end

  def sub_layer_type(id)
    Layer.new("#{@s_url}/#{id}").type
  end

end
