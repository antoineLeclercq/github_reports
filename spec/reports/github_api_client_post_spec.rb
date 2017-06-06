require "sinatra/base"
require "webmock/rspec"
require "reports/github_api_client"

class FakeGitHub < Sinatra::Base
  attr_reader :gists

  def initialize
    super
    @gists = []
  end

  post '/gists' do
    content_type :json

    payload = JSON.parse(request.body.read)
    if payload['description'].empty? ||
      payload['files'].keys.any? { |file_name| file_name.empty? } ||
      payload['files'].values.any? { |file_content| file_content.empty? }
      status 422
      { message: "Validation Failed!" }.to_json
    else
      status 201
      @gists << payload
      { html_url: 'https://gist.github.com/username/abcdefg12345678' }.to_json
    end
  end
end

module Reports
  RSpec.describe GitHubAPIClient do
    let(:fake_server) { FakeGitHub.new! }

    before(:each) do
      stub_request(:any, /api.github.com/).to_rack(fake_server)
    end

    it 'creates a private gist' do
      client = GitHubAPIClient.new

      gist_url = client.create_private_gist('gist description', 'test_gist.rb', 'puts "Hello test"')

      expect(gist_url).to eq('https://gist.github.com/username/abcdefg12345678')
       expect(fake_server.gists.first).to eql({
        'description' => 'gist description',
        'public' => false,
        'files' => {
          'test_gist.rb' => {
            'content' => 'puts "Hello test"'
          }
        }
      })
    end

    it 'raises an error when gist creation fails' do
      client = GitHubAPIClient.new
      expect {
        client.create_private_gist('gist description', '', 'puts "Hello test"')
      }.to raise_error(GistCreationFailure)
    end
  end
end
