require 'sinatra/base'
require 'rack'
require 'sprockets'

require 'etcd'

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

    def self.initialize_context(config)
      {}.tap do |ctx|
        ctx[:etcd] = Etcd.client(config[:etcd] || {})
      end
    end

    def self.rack(config={})
      klass = self

      context = initialize_context(config)
      app = lambda { |env|
        env['etcweb'] = context
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

    helpers do
      def context
        request.env['etcweb']
      end

      def etcd
        context[:etcd]
      end
    end

    get '/' do
    end
  end
end
