require 'sinatra/base'
require 'rack'
require 'sprockets'

module Etcweb
  class App < Sinatra::Base
    set :root, File.expand_path(File.join(__dir__, '..', '..', 'app'))

    def self.sprockets
      Sprockets::Environment.new.tap { |env|
        env.append_path "#{self.root}/javascripts"
        env.append_path "#{self.root}/stylesheets"
        env.append_path "#{self.root}/images"
        env.append_path "#{self.root}/vendor/assets/bower_components"
      }
    end

    def self.rack(config={})
      klass = self
      app = lambda { |env|
        env['etcweb.config'] = config
        klass.call(env)
      }
      Rack::Builder.app do
        map '/assets' do
          run klass.sprockets
        end

        map '/' do
          run app
        end
      end
    end

    get '/' do
    end
  end
end
