require 'spec_helper'

def app
  AsanaService::API
end

describe AsanaService::API do
  include Rack::Test::Methods

  describe 'GET /asana' do

    before do
      stub_request(:get, "https://2qHzs808.Mxzrvd3juGQ8HdQF5SFrXCE:@app.asana.com/api/1.0/users/me.json").
        with(:headers => {'Accept'=>'application/json', 'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3', 'User-Agent'=>'Ruby'}).
        to_return(:status => 200, :body => '{"data":{"name":"dogboard","id":"123"}}', :headers => {"Content-Type" => "application/json; charset=UTF-8"})
    end
    
    it 'returns a representation of a user from Asana' do
      get '/asana'
      expect(last_response.body).to eq(name: 'dogboard')
    end
  
  end

end