# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require 'gis_scraper/version'

Gem::Specification.new do |s|
  s.name          = 'gis_scraper'
  s.version       = GisScraper::VERSION
  s.authors       = ['Bruce Steedman']
  s.email         = ['bruce.steedman@gmail.com']

  s.summary       = 'Scrapes ArcGIS data from MapServer REST API'
  s.description   = 'Scrapes ArcGIS data from MapServer REST API'
  s.required_ruby_version = '>= 2.0'
  s.license = 'MIT'

  s.files = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(spec)/}) }
  s.bindir        = 'exe'
  s.executables   = s.files.grep(%r{^exe/}) { |f| File.basename(f) }
  s.require_paths = ['lib']

  s.add_development_dependency 'bundler', '~> 1.11'
  s.add_development_dependency 'rake', '~> 10.0'
  s.add_development_dependency 'rspec', '~> 3.4'

  s.add_runtime_dependency 'mechanize', '~> 2.7'
  s.add_runtime_dependency 'parallel', '~> 1.6'
  s.add_development_dependency 'pg', '~> 0.18'
end
