require 'sinatra/base'
require 'json'
require 'faml'
require 'rack'
require 'sass'
require 'sprockets'
require 'sprockets/helpers'

require 'bootstrap-sass'

require 'etcd'
require 'etcd/etcvault'

require 'omniauth'

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

    def self.initialize_etcd(config)
      # etcd v0.2.4 (latest as of Mar 31, 2015) doesn't set TLS parameters in constructor
      # https://github.com/ranjib/etcd-ruby/commit/bf2c7e6dee8b2c07f85cca8541d16dcbef67cc1a
      Etcd.client(config).tap do |etcd|
        etcd.config.ca_file = config[:ca_file]
        etcd.config.ssl_cert = config[:ssl_cert]
        etcd.config.ssl_key = config[:ssl_key]
      end
    end

    def self.initialize_context(config)
      {}.tap do |ctx|
        ctx[:etcd] = initialize_etcd(config[:etcd] || {})
        ctx[:config] = config
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
        @key ||= "/#{params[:splat] && params[:splat].first}".tap do |k|
          k.concat("/#{params[:child]}") if params[:child]
          k.sub!(%r{^//}, '/') # for child of root
        end
      end

      def etcvault?
        !!context[:config][:etcvault]
      end

      def etcvault_keys_cache_ttl
        context[:config][:etcvault_keys_cache_ttl] || 30
      end

      def etcvault_keys
        return [] unless etcvault?
        context[:etcvault_keys] ||= {}
        if context[:etcvault_keys][:expiry].nil? || context[:etcvault_keys][:expiry] <= Time.now
          context[:etcvault_keys] = {
            expiry: Time.now + etcvault_keys_cache_ttl,
            keys:   etcd.etcvault_keys
          }
        end
        context[:etcvault_keys][:keys]
      end

      def auth_enabled?
        context[:config][:auth]
      end

      def omniauth_strategy
        context[:config][:auth][:omniauth] or raise 'no config.auth.omniauth specified'
      end

      def auth_allow_policy_proc
        context[:config][:auth][:allow_policy_proc] || proc { true }
      end

      def auth_after_login_proc
        context[:config][:auth][:after_login_proc] || proc { }
      end

      def current_user
        session[:user]
      end
    end

    before do
      next if request.path_info.start_with?('/auth')
      next unless auth_enabled?

      if current_user && instance_eval(&auth_allow_policy_proc)
        next
      end

      if request.get?
        session[:back_to] = request.fullpath
        redirect "/auth/#{omniauth_strategy}"
      else
        halt 401
      end
    end

    post '/logout' do
      session[:user] = nil
      redirect '/'
    end

    post '/auth/:strategy/callback' do
      auth = env['omniauth.auth']
      session[:user] = {
        uid: auth[:uid],
        info: auth[:info],
        provider: auth[:provider],
      }
      instance_eval(&auth_after_login_proc)
      redirect session.delete(:back_to) || "/"
    end

    get '/' do
      redirect "/keys/"
    end

    get '/keys' do
      redirect "/keys/"
    end

    get '/keys/*' do
      begin
        @etcd_response = etcd.get(key)
      rescue Etcd::NotDir, Etcd::KeyNotFound
        halt 404
      rescue Etcd::Error => e
        status 400
        return haml(:etcd_error, locals: {error: e})
      end

      haml :keys
    end

    put '/keys/*' do
      options = {value: params[:value]}

      if params[:etcvault_key] && !params[:etcvault_key].empty?
        unless etcvault_keys.include?(params[:etcvault_key])
          halt 404
        end
        options[:value] = "ETCVAULT::plain:#{params[:etcvault_key]}:#{options[:value]}::ETCVAULT"
      end

      if params[:dir]
        options.replace(dir: true)
      end

      options[:ttl] = params[:ttl].to_i if params[:ttl]

      begin
        @etcd_response = etcd.set(key, options)
      rescue Etcd::Error => e
        status 400
        return haml(:etcd_error, locals: {error: e})
      end

      redirect "/keys#{key}"
    end

    delete '/keys/*' do
      begin
        options = {recursive: !!params[:recursive]}
        @etcd_response = etcd.delete(key, options)
      rescue Etcd::NotDir, Etcd::KeyNotFound
        halt 404
      rescue Etcd::Error => e
        status 400
        return haml(:etcd_error, locals: {error: e})
      end

      parent = key.split(?/).tap(&:pop).join(?/)
      redirect "/keys#{parent}"
    end

    get '/etcvault_keys' do
      content_type :json

      etcvault_keys.to_json
    end
  end
end
