# encoding: utf-8
$:.push File.expand_path('../lib', __FILE__)

Gem::Specification.new do |gem|
  gem.name        = "fluentd-plugin-record-modifier"
  gem.description = "Output filter plugin for modifying each event record"
  gem.homepage    = "https://github.com/repeatedly/fluent-plugin-record-modifier"
  gem.summary     = gem.description
  gem.version     = File.read("VERSION").strip
  gem.authors     = ["Masahiro Nakagawa"]
  gem.email       = "repeatedly@gmail.com"
  gem.has_rdoc    = false
  #gem.platform    = Gem::Platform::RUBY
  gem.files       = `git ls-files`.split("\n")
  gem.test_files  = `git ls-files -- {test,spec,features}/*`.split("\n")
  gem.executables = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  gem.require_paths = ['lib']

  gem.add_dependency "fluentd", "~> 0.11.0"
  gem.add_development_dependency "rake", ">= 0.9.2"
  gem.add_development_dependency "rspec", ">= 2.13.0"
end
