require 'mechanize'

class JSONParser < Mechanize::File
  attr_reader :json

  def initialize(uri=nil, response=nil, body=nil, code=nil)
    super(uri, response, body, code)
    @json = JSON.parse(body)
  end
end

class Scraper

  SCHEME = 'http://'
  DOMAIN = 'gps.digimap.gg/'
  ROOT = 'arcgis/rest/services/'

  def initialize(service, layer_num)
    @service = service
    @layer_num = layer_num
    @url = url
    @agent = Mechanize.new
    @agent.pluggable_parser['text/plain'] = JSONParser
    @pk = pk
    @max = max # maxRecordCount - usually 1000
    @form = form
  end

  def pk
    @agent.get(url + '?f=pjson').json['fields'].first['name']
  end

  def max
    @agent.get(url + '?f=pjson').json['maxRecordCount'].to_i
  end

  def form
    @agent.get(url + '/query').forms.first
  end

  def count
    set_query_params
    @form.submit(@form.buttons[1]).json['count'].to_i
  end

  def set_query_params(loop_num = nil)
    @form.fields[0].value = where_text(loop_num)
    @form.radiobuttons[4].check unless loop_num # count only true
    @form.fields[6].value = '*'
    @form.field_with(name: 'f').options[1].select # for JSON
  end

  def data(n)
    set_query_params(n)
    @form.submit(@form.buttons[1]).json
  end

  def features
    (0...num_loops).map { |n| data(n)['features'] }.flatten
  end

  def all_data
    data(0).merge({ 'features' => features })
  end

  private

  def url
    SCHEME + DOMAIN + ROOT + @service + "/MapServer/#{@layer_num}"
  end

  def num_loops
    (count.to_f/@max).ceil
  end

  def where_text(n)
    return "#{pk} > 0" unless n
    "#{pk} > #{n * @max} AND #{pk} <= #{(n + 1) * @max}"
  end

end
