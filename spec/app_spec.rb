require 'spec_helper'
require 'uri'
require 'etcweb/app'

describe Etcweb::App, type: :app do
  let(:etcd) { double("etcd", config: double('etcd.config').as_null_object) }

  before do
    allow(Etcd).to receive(:client).and_return(etcd)
  end

  before(:all) do
    OmniAuth.config.add_mock(:app_test, {})
  end

  [false, true].each do |auth|
    context(auth ? "with auth" : "without auth") do
      if auth
        before do
          app_config[:auth] = {
            omniauth: 'app_test',
          }

          begin
            env['omniauth.auth'] = OmniAuth.config.mock_auth[:app_test]
            response = post('/auth/app_test/callback', {}, env)
            current_session.instance_variable_set(:@last_response, nil)

            expect(response).to be_a_redirection
          ensure
            env['omniauth.auth'] = nil
          end
        end
      end

      describe "GET /" do
        subject { get '/', {}, env }

        it "redirects to /keys/" do 
          expect(response).to be_a_redirection
          expect(URI.parse(response.location).path).to eq '/keys/'
        end
      end

      describe "GET /keys" do
        subject { get '/keys', {}, env }

        it "redirects to /keys/" do 
          expect(response).to be_a_redirection
          expect(URI.parse(response.location).path).to eq '/keys/'
        end
      end

      describe "GET /keys/*" do
        context "without splat" do
          subject { get '/keys/', {}, env }

          it "queries key '/'" do
            etcd_response = double('etcd_response')
            expect(etcd).to receive(:get).with('/').and_return(etcd_response)

            expect(response).to be_ok
            expect(render[:ivars][:@etcd_response]).to eq(etcd_response)
          end
        end

        context "with splat" do
          subject { get '/keys/keyname', {}, env }

          it "queries key '/keyname'" do
            etcd_response = double('etcd_response')
            expect(etcd).to receive(:get).with('/keyname').and_return(etcd_response)

            expect(response).to be_ok
            expect(render[:ivars][:@etcd_response]).to eq(etcd_response)
          end
        end

        context "when key not found" do
          subject { get '/keys/keyname', {}, env }

          it "returns 404" do
            expect(etcd).to receive(:get).with('/keyname').and_raise(Etcd::NotDir.new)

            expect(response).to be_not_found
          end
        end

        context "when error" do
          subject { get '/keys/keyname', {}, env }

          it "returns 400" do
            error = Etcd::Error.new
            expect(etcd).to receive(:get).with('/keyname').and_raise(error)

            expect(response.status).to eq 400
            expect(render[:locals][:error]).to eq error
          end
        end
      end

      describe "PUT /keys/*" do
        let(:params) { {value: 'var'} }
        subject { put '/keys/foo', params, env }

        describe "(normal)" do
          it "sets value to etcd" do
            expect(etcd).to receive(:set).with('/foo', value: 'var').and_return(double('etcd_response'))
            expect(response).to be_a_redirection
            expect(URI.parse(response.location).path).to eq '/keys/foo'
          end
        end

        describe "(CR+LF values)" do
          let(:params) { {value: "a\r\nb"} }
          it "sets value to etcd" do
            expect(etcd).to receive(:set).with('/foo', value: "a\nb").and_return(double('etcd_response'))
            expect(response).to be_a_redirection
            expect(URI.parse(response.location).path).to eq '/keys/foo'
          end
        end

        context "with dir" do
          let(:params) { {dir: '1'} }

          it "creates directory on etcd" do
            expect(etcd).to receive(:set).with('/foo', dir: true).and_return(double('etcd_response'))
            expect(response).to be_a_redirection
            expect(URI.parse(response.location).path).to eq '/keys/foo'
          end
        end

        context "with ttl" do
          let(:params) { {value: 'var', ttl: '60'} }

          it "sets value with ttl" do
            expect(etcd).to receive(:set).with('/foo', value: 'var', ttl: 60).and_return(double('etcd_response'))
            expect(response).to be_a_redirection
            expect(URI.parse(response.location).path).to eq '/keys/foo'
          end
        end

        context "with child" do
          let(:params) { {value: 'var', child: 'child'} }

          it "sets value to etcd" do
            expect(etcd).to receive(:set).with('/foo/child', value: 'var').and_return(double('etcd_response'))
            expect(response).to be_a_redirection
            expect(URI.parse(response.location).path).to eq '/keys/foo/child'
          end
        end

        context "when got error" do
          it "returns 400" do
            error = Etcd::Error.new
            expect(etcd).to receive(:set).with('/foo', value: 'var').and_raise(error)

            expect(response.status).to eq 400
            expect(render[:locals][:error]).to eq error
          end
        end

        context "with etcvault_key" do
          before do
            app_config[:etcvault] = true
          end

          before do
            allow(etcd).to receive(:etcvault_keys).and_return(%w(the-key))
          end

          context "when key exists" do
            let(:params) { {value: 'var', etcvault_key: 'the-key'} }

            it "sets etcvault plain container with specified key name" do
              expect(etcd).to receive(:set).with('/foo', value: "ETCVAULT::plain:the-key:var::ETCVAULT").and_return(double('etcd_response'))
              expect(response).to be_a_redirection
              expect(URI.parse(response.location).path).to eq '/keys/foo'
            end
          end

          context "when key doesn't exists" do
            let(:params) { {value: 'var', etcvault_key: 'unexist-key'} }

            it "returns 404" do
              expect(response).to be_not_found
            end
          end
        end
      end

      describe "DELETE /keys/*" do
        let(:params) { {} }
        subject { delete '/keys/foo', params, env }

        describe "(normal)" do
          it "deletes key from etcd" do
            expect(etcd).to receive(:delete).with('/foo', recursive: false).and_return(double('etcd_response'))
            expect(response).to be_a_redirection
            expect(URI.parse(response.location).path).to eq '/keys'
          end
        end


        describe "for keys in subdirectories" do
          subject { delete '/keys/foo/bar', params, env }

          it "redirects to parent" do
            expect(etcd).to receive(:delete).with('/foo/bar', recursive: false).and_return(double('etcd_response'))
            expect(response).to be_a_redirection
            expect(URI.parse(response.location).path).to eq '/keys/foo'
          end
        end

        context "with recursive" do
          let(:params) { {recursive: '1'} }

          it "sets value to etcd" do
            expect(etcd).to receive(:delete).with('/foo', recursive: true).and_return(double('etcd_response'))
            expect(response).to be_a_redirection
            expect(URI.parse(response.location).path).to eq '/keys'
          end
        end

        context "when got error" do
          it "returns 400" do
            error = Etcd::Error.new
            expect(etcd).to receive(:delete).with('/foo', recursive: false).and_raise(error)

            expect(response.status).to eq 400
            expect(render[:locals][:error]).to eq error
          end
        end
      end
    end
  end

  describe "auth" do
    context "when enabled" do
      before do
        app_config[:auth] = {
          omniauth: 'app_test',
        }
      end

      context "without session" do
        describe "GET /" do
          subject { get '/' }

          it "denies access, redirects to omniauth" do 
            expect(response).to be_a_redirection
            expect(URI.parse(response.location).path).to eq '/auth/app_test'
          end
        end

        describe "GET /keys" do
          subject { get '/keys' }

          it "denies access, redirects to omniauth" do 
            expect(response).to be_a_redirection
            expect(URI.parse(response.location).path).to eq '/auth/app_test'
          end
        end

        describe "GET /keys/*" do
          subject { get '/keys/' }

          it "denies access, redirects to omniauth" do 
            expect(response).to be_a_redirection
            expect(URI.parse(response.location).path).to eq '/auth/app_test'
          end
        end

        describe "PUT /keys/*" do
          let(:params) { {value: 'var'} }
          subject { put '/keys/foo', params }

          it "denies access" do 
            expect(response.status).to eq 401
          end
        end

        describe "DELETE /keys/*" do
          let(:params) { {} }
          subject { delete '/keys/foo', params }

          it "denies access" do 
            expect(response.status).to eq 401
          end
        end
      end
    end

    context "with allow_policy_proc" do
      before do
        app_config[:auth] = {
          omniauth: 'app_test',
          allow_policy_proc: proc { false },
        }
        begin
          env['omniauth.auth'] = OmniAuth.config.mock_auth[:app_test]
          response = post('/auth/app_test/callback', {}, env)
          current_session.instance_variable_set(:@last_response, nil)

          expect(response).to be_a_redirection
        ensure
          env['omniauth.auth'] = nil
        end
      end

      describe "GET /" do
        subject { get '/', {}, env }

        it "denies access with 403" do
          expect(response.status).to eq 403
        end
      end

      describe "GET /keys" do
        subject { get '/keys', {}, env }

        it "denies access with 403" do
          expect(response.status).to eq 403
        end
      end

      describe "PUT /keys/*" do
        let(:params) { {value: 'var'} }
        subject { put '/keys/foo', params, env }

        it "denies access" do 
          expect(response.status).to eq 403
        end
      end

      describe "DELETE /keys/*" do
        let(:params) { {} }
        subject { delete '/keys/foo', params, env }

        it "denies access" do 
          expect(response.status).to eq 403
        end
      end
    end
  end
end
