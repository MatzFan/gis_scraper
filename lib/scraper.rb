# require 'mechanize'

# class JSONParser < Mechanize::File
#   attr_reader :json

#   def initialize(uri=nil, response=nil, body=nil, code=nil)
#     super(uri, response, body, code)
#     @json = JSON.parse(body)
#   end
# end

# class IdsDontMatchError < StandardError; end

class Scraper

#   Linguistics.use(:en) # for plural method

  DOMAIN = 'https://gps.digimap.gg/'
#   URL, KEYS, COLUMNS = '', [], [] # subclasses must overide

#   attr_reader :form

#   def initialize(lower_id = 0, upper_id = 0)
#     @lower_id, @upper_id = lower_id, upper_id
#     @id_array = (@lower_id..@upper_id).to_a
#     @agent = Mechanize.new
#     @agent.pluggable_parser['text/plain'] = JSONParser # not 'application/json'..??
#     @keys = keys
#     @form = form
#     @json = json
#     validate
#     setup_hash_key_methods
#     @features = features
#     @atts = atts
#     setup_accessor_methods
#   end

#   def keys
#     self.class.const_get(:KEYS).zip(self.class.const_get(:COLUMNS)).map { |arr| Hash[*arr] }.inject({}) { |m, e| m.merge(e) }
#   end

#   def form
#     @agent.get(DOMAIN + self.class.const_get(:URL)).forms.first
#   end

#   def json
#     set_query_params
#     @form.submit(@form.buttons[1]).json
#   end

#   def validate
#     raise Error unless @form.fields.map(&:name) == FIELDS &&
#     @form.radiobuttons.map(&:name) == RADIOS
#   end

#   def setup_hash_key_methods
#     (self.class.const_get(:KEYS) + %w(features attributes geometry x y)).each do |key|
#       Hash.send(:define_method, key.downcase) { self[key] }
#     end
#   end

#   def setup_accessor_methods # meta program accessor methods for all KEY fields
#     self.class.const_get(:KEYS).map(&:downcase).each do |key|
#       self.class.send(:define_method, key.en.plural) { @atts.map(&key.to_sym) }
#     end
#     # and for geometry - :xs, :ys
#     self.class.send(:define_method, 'xes') { geometry.map &:x }
#     self.class.send(:define_method, 'yes') { geometry.map &:y }
#   end

#   def features
#     @json['features']
#   end

#   def atts
#     @features.map(&:attributes)
#   end

#   def geometry
#     @features.map(&:geometry)
#   end

#   def rings # the shape's polygon rings - or nil for a point
#     geometry[0]['rings']
#   end

#   def set_query_params
#     @form.fields[0].value = query_string # SQL 'WHERE' clause
#     @form.fields[6].value = self.class.const_get(:KEYS).join(',') # output fields
#     @form.field_with(name: 'f').options[1].select # for JSON
#   end

#   def query_string
#     "OBJECTID >= #{@lower_id} AND OBJECTID <= #{@upper_id}"
#   end

#   def hash_key(key) # monkey patch Hash for each JSON key required
#     Hash.send(:define_method, key.downcase) { self[key] }
#   end

#   def num_records
#     agent = Mechanize.new
#     agent.pluggable_parser['text/plain'] = JSONParser
#     form = agent.get(DOMAIN + self.class.const_get(:URL)).forms.first
#     form.fields[0].value = "OBJECTID > 0"
#     form.radiobuttons[4].check # count only true
#     form.field_with(name: 'f').options[1].select # for JSON
#     form.submit(form.buttons[1]).json['count'].to_i
#   end

#   def data
#     return array_of_hashes.map { |arr| arr.inject &:merge } if rings # otherwise add point coords
#     coords.zip(array_of_hashes).map(&:flatten).map { |arr| arr.inject &:merge }
#   end

#   def coords
#     xes.map { |x| Hash[x: x] }.zip(yes.map { |y| Hash[y: y] })
#   end

#   def array_of_hashes
#     self.class.const_get(:KEYS)[1..-1].inject(hashy(self.class.const_get(:KEYS)[0])) do |m, e|
#       m.zip(hashy e)
#     end.map &:flatten
#   end

#   def hashy(key)
#     self.send(key.downcase.en.plural.to_sym).map do |e|
#       Hash[@keys[key] => (e ? process(key, e) : nil)]
#     end
#   end

#   def process(k, d) # overide depending on processing needs of specific data
#     return d
#   end

end
