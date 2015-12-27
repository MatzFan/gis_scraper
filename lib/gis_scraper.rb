require 'yaml'
require 'mechanize'
require 'parallel'

require 'gis_scraper/version'
require 'gis_scraper/feature_scraper'
require 'gis_scraper/layer'

# stackoverflow.com/questions/6233124/where-to-place-access-config-file-in-gem
module GisScraper

  @config = {threads: 8} # threads used for scraping
  @valid_keys = @config.keys

  def self.configure(opts = {})
    opts.each { |k,v| @config[k.to_sym] = v if @valid_keys.include? k.to_sym }
  end

  def self.configure_with(path_to_yaml_file)
    begin
      config = YAML::load(IO.read(path_to_yaml_file))
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

end
