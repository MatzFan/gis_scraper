require 'mechanize'

require_relative 'scraper'

class Layer

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
    @layer_type = layer_type
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

  def layer_type
    @page_json['type']
  end

  def layer_ids
    @layer_type == 'Feature Layer' ? [@id] : group_layer_ids
  end

  def group_layer_ids
    @page_json['subLayers'].map { |layer| layer['id'] }
  end

  def layers_data_json_list
    @layer_ids.map { |id| Scraper.new("#{@s_url}/#{id}").json_data }
  end

  def layer_name_list
    @layer_ids.map { |id| Scraper.new("#{@s_url}/#{id}").name }
  end

  def write
    layer_name_list.zip(layers_data_json_list).each do |arr|
      File.write(@path + "/#{arr.first}.json", arr.last)
    end
  end

end
