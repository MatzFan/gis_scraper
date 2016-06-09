# scrapes feature layers
class FeatureScraper
  API_CALL_LIMIT = 1000
  STRING = 'esriFieldTypeString'.freeze
  VARCHAR_MAX_SIZE = 10_485_760 # max size for PostgreSQL VARCHAR

  attr_reader :name

  def initialize(url)
    @url = url
    @layer = layer
    @json = json
    @name = name
    @pk = pk
    @max = max # maxRecordCount - usually 1000
    @loops = loops
    @threads = GisScraper.config[:threads]
  end

  def json_data
    query_without_features.merge('features' => all_features(@threads)).to_json
  end

  private

  def query_without_features # check_field_length not needed ogr2ogr >= 1.11.5
    check_field_length @layer.query(where: '1=0')
  end

  def layer
    ArcREST::Layer.new(@url)
  end

  def json
    @layer.json
  end

  def name
    @layer.name
  end

  def renderer
    @layer.drawing_info['renderer']
  end

  def pk
    @json['fields'].select { |f| f['type'] == 'esriFieldTypeOID' }[0]['name']
  end

  def max
    @layer.max_record_count || API_CALL_LIMIT
  end

  def count
    @layer.count
  end

  def features(n)
    @layer.features(where: where_text(n))
  end

  def check_field_length(hash) # https://trac.osgeo.org/gdal/ticket/6529
    hash.merge check_fields(hash['fields'])
  end

  def check_fields(fields)
    { 'fields' => fields.map { |f| f['type'] == STRING ? esri_string(f) : f } }
  end

  def esri_string(fields)
    Hash[fields.map { |k, v| [k, k == 'length' ? truncate(v) : v] }] # nice :)
  end

  def truncate(length)
    length > VARCHAR_MAX_SIZE ? 0 : length
  end

  def all_features(threads)
    Parallel.map(0...@loops, in_threads: threads) { |n| features(n) }.flatten
  end

  def loops
    (count.to_f / @max).ceil
  end

  def where_text(n)
    n ? "#{pk} > #{n * @max} AND #{pk} <= #{(n + 1) * @max}" : "#{pk} > 0"
  end
end
