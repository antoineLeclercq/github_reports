require 'spec_helper'
require_relative '../vcr_helper'
require 'reports/github_api_client'

module Reports
  RSpec.describe GitHubAPIClient do
    it "can be initialized" do
      subject
    end

    let(:octocat_info) { User.new('The Octocat', 'San Francisco', 7) }

    it 'successfully retrieves user information', :vcr do
      client = GitHubAPIClient.new

      info = client.user_info('octocat')

      expect(info.name).to eq(octocat_info.name)
      expect(info.location).to eq(octocat_info.location)
      expect(info.public_repos_count).to eq(octocat_info.public_repos_count)
    end

    it 'raises an error if user does not exist', :vcr do
      client = GitHubAPIClient.new
      expect { client.user_info('non_existent_user1234') }.to raise_error(NonexistentUser)
    end
  end
end
