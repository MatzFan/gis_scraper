require 'mechanize'

class JSONParser < Mechanize::File
  attr_reader :json

  def initialize(uri=nil, response=nil, body=nil, code=nil)
    super(uri, response, body, code)
    @json = JSON.parse(body)
  end
end

class FeatureScraper

  attr_reader :name

  def initialize(url)
    @url = url
    @agent = Mechanize.new
    @agent.pluggable_parser['text/plain'] = JSONParser
    @layer = layer # hash
    @name = name
    @pk = pk
    @max = max # maxRecordCount - usually 1000
    @form = form
  end

  def layer
    @agent.get(@url + '?f=pjson').json
  end

  def name
    @layer['name']
  end

  def pk
    @layer['fields'].select { |f| f['type'] == 'esriFieldTypeOID' }[0]['name']
  end

  def max
    @layer['maxRecordCount'].to_i
  end

  def form
    @agent.get(@url + '/query').forms.first
  end

  def count
    set_query_params
    @form.submit(@form.buttons[1]).json['count'].to_i
  end

  def set_query_params(loop_num = nil)
    @form.fields[0].value = where_text(loop_num)
    loop_num ? @form.radiobuttons[4].uncheck : @form.radiobuttons[4].check # count only true
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

  def json_data
    data(0).merge({ 'features' => features }).to_json
  end

  private

  def num_loops
    (count.to_f/@max).ceil
  end

  def where_text(n)
    n ? "#{pk} > #{n * @max} AND #{pk} <= #{(n + 1) * @max}" : "#{pk} > 0"
  end

end
