require 'sinatra/base'
require 'rack'

module Etcweb
  class App < Sinatra::Base
    def self.rack(config={})
      app = lambda { |env|
        env['etcweb.config'] = config
        self.call(env)
      }
      Rack::Builder.app do
        run app
      end
    end

    get '/' do
    end
  end
end
