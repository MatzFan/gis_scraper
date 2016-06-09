require 'yaml'
require 'arcrest'
# require 'mechanize'
require 'parallel'
require 'pg'

require 'gis_scraper/version'
require 'gis_scraper/feature_scraper'
require 'gis_scraper/layer_writer'

# stackoverflow.com/questions/6233124/where-to-place-access-config-file-in-gem
module GisScraper
  @config = { threads: 8, output_path: '~/Desktop', host: 'localhost',
              port: 5432, dbname: 'postgres', user: 'postgres', password: nil,
              srs: nil }
  @valid_keys = @config.keys

  def self.configure(opts = {})
    opts.each { |k, v| @config[k.to_sym] = v if @valid_keys.include? k.to_sym }
  end

  def self.configure_with(path_to_yaml_file)
    begin
      config = YAML.load(IO.read(path_to_yaml_file))
    rescue Errno::ENOENT
      puts "YAML configuration file couldn't be found. Using defaults"
      return
    rescue Psych::SyntaxError
      puts 'YAML configuration file contains invalid syntax. Using defaults'
      return
    end

    configure(config)
  end

  def self.config
    @config
  end

  # shared by FeatureScraper & Layer
  # class JSONParser < Mechanize::File
  #   attr_reader :json

  #   def initialize(uri = nil, response = nil, body = nil, code = nil)
  #     super(uri, response, body, code)
  #     @json = JSON.parse(body)
  #   end
  # end
end
