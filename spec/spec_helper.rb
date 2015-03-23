require 'rack/test'
require 'etcweb'

module AppSpecHelper
  include Rack::Test::Methods

  def app_config
    @app_config ||= {
    }
  end

  def app
    ::Etcweb::App.rack(app_config)
  end

  def response
    subject; last_response
  end

  def env
    @env ||= {'rack.session' => session}
  end

  def session
    @session ||= {}
  end

  def last_render
    @renders.last
  end

  def render
    subject; @renders.last
  end

  def self.included(k)
    k.module_eval do
      before(:example) do |example|
        @renders = []
        unless example.metadata[:render]
          allow_any_instance_of(Etcweb::App).to receive(:render) do |instance, *args, &block|
            @renders << {engine: args[0], data: args[1], options: args[2] || {}, locals: args[3] || {}, ivars: args[4] || {}}
            ""
          end
          Etcweb::App.class_eval do
            alias render_orig render
            def render(*args)
              render_orig *args, Hash[self.instance_variables.map{ |k| [k, instance_variable_get(k)] }]
            end
            private :render, :render_orig
          end
        end
      end
    end
  end
end

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.include AppSpecHelper, type: :app
end
