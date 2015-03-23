require 'spec_helper'
require 'etcweb/app'

describe Etcweb::App, type: :app do
  describe "GET /" do
    subject { get '/' }

    it "returns 200" do 
      expect(response.status).to eq 200
    end
  end
end

