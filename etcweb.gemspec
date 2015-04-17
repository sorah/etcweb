# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'etcweb/version'

Gem::Specification.new do |spec|
  spec.name          = "etcweb"
  spec.version       = Etcweb::VERSION
  spec.authors       = ["Shota Fukumori (sora_h)"]
  spec.email         = ["sorah@cookpad.com"]

  spec.summary       = %q{Web UI for etcd}
  spec.description   = nil
  spec.homepage      = "https://github.com/sorah/etcweb"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "sinatra", ">= 1.4.5"
  spec.add_dependency "etcd", ">= 0.2.4"
  spec.add_dependency "etcd-etcvault", ">= 1.1.0"
  spec.add_dependency "sprockets", ">= 2.12.3", "< 3"
  spec.add_dependency "faml", ">= 0.2.0"
  spec.add_dependency "bootstrap-sass", '~> 3.3.4'
  spec.add_dependency "sprockets-helpers"
  spec.add_dependency "omniauth"

  spec.add_development_dependency "bundler", "~> 1.9"
  spec.add_development_dependency "rake", "~> 10.0"

  spec.add_development_dependency "rspec", "~> 3.2.0"

  spec.add_development_dependency "rack-test"
end
