require 'sinatra/base'
require 'faml'
require 'rack'
require 'sass'
require 'sprockets'
require 'sprockets/helpers'

require 'bootstrap-sass'

require 'etcd'

module Etcweb
  class App < Sinatra::Base
    set :method_override, true
    set :show_exceptions, false
    set :root, File.expand_path(File.join(__dir__, '..', '..', 'app'))
    set :sprockets, Sprockets::Environment.new.tap { |env|
        env.append_path "#{self.root}/javascripts"
        env.append_path "#{self.root}/stylesheets"
        env.append_path "#{self.root}/images"
        env.append_path "#{self.root}/bower_components"
      }

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
      include Sprockets::Helpers

      def context
        request.env['etcweb']
      end

      def etcd
        context[:etcd]
      end

      def key
        @key ||= "/#{params[:splat] && params[:splat].first}"
      end
    end

    get '/' do
      redirect "/keys/"
    end

    get '/keys/*' do
      begin
        @etcd_response = etcd.get(key)
      rescue Etcd::NotDir
        halt 404
      end
      haml :keys
    end

    post '/keys/*' do
      begin
        @etcd_response = etcd.get(key)
      rescue Etcd::NotDir
        halt 404
      end
      haml :keys
    end
  end
end
