# scrapes feature layers
class FeatureScraper
  API_CALL_LIMIT = 1000
  STRING = 'esriFieldTypeString'.freeze
  VARCHAR_MAX_SIZE = 10_485_760

  attr_reader :name

  def initialize(url)
    @url = url
    @agent = Mechanize.new
    @agent.pluggable_parser['text/plain'] = GisScraper::JSONParser
    @layer = layer # hash of json
    @name = name
    @pk = pk
    @max = max # maxRecordCount - usually 1000
    @form = form
    @loops = loops
    @threads = GisScraper.config[:threads]
  end

  def json_data
    data(0).merge('features' => features(@threads)).to_json
  end

  private

  def layer
    @agent.get(@url + '?f=pjson').json
  end

  def name
    @layer['name']
  end

  def renderer
    @layer['drawingInfo']['renderer']
  end

  def pk
    @layer['fields'].select { |f| f['type'] == 'esriFieldTypeOID' }[0]['name']
  end

  def max
    @layer['maxRecordCount'] ? @layer['maxRecordCount'].to_i : API_CALL_LIMIT
  end

  def form
    @agent.get(@url + '/query').forms.first
  end

  def count
    fill_form
    @form.submit(@form.submits[1]).json['count'].to_i
  end

  def fill_form(loop_num = nil)
    @form.field_with(name: 'where').value = where_text(loop_num)
    loop_num ? count_only_radio_button.uncheck : count_only_radio_button.check
    @form.field_with(name: 'outFields').value = '*'
    @form.field_with(name: 'f').value = 'pjson'
  end

  def count_only_radio_button
    @form.radiobutton_with(name: 'returnCountOnly')
  end

  def data(n)
    fill_form(n)
    check_field_length @form.submit(@form.buttons[1]).json
  end

  def check_field_length(hash)
    hash.merge check_fields(hash['fields'])
  end

  def check_fields(fields)
    { 'fields' => fields.map { |f| f['type'] == STRING ? esri_string(f) : f } }
  end

  def esri_string(fields)
    Hash[fields.map { |k, v| [k, k == 'length' ? truncate(v) : v] }] # nice :)
  end

  def truncate(length)
    length > VARCHAR_MAX_SIZE ? VARCHAR_MAX_SIZE : length
  end

  def features(t)
    Parallel.map(0...@loops, in_threads: t) { |n| data(n)['features'] }.flatten
  end

  def loops
    (count.to_f / @max).ceil
  end

  def where_text(n)
    n ? "#{pk} > #{n * @max} AND #{pk} <= #{(n + 1) * @max}" : "#{pk} > 0"
  end
end
