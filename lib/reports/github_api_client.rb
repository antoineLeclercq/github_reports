require 'faraday'
require 'json'
require_relative 'middleware/logging'
require_relative 'middleware/authentication'

module Reports
  class Error < StandardError; end
  class NonexistentUser < Error; end
  class RequestFailure < Error; end

  User = Struct.new(:name, :location, :public_repos_count)
  Repository = Struct.new(:name, :url)

  VALID_STATUS_CODES = [200, 302, 401, 403, 404, 422]

  class GitHubAPIClient
    attr_reader :logger, :token

    def initialize(token)
      @token = token
    end

    def user_info(username)
      headers = { 'Authorization' => "token #{token}" }
      url = "https://api.github.com/users/#{username}"

      response = connection.get(url, nil, headers)

      if !VALID_STATUS_CODES.include?(response.status)
        raise RequestFailure, JSON.parse(response.body)['message']
      end

      if response.status == 404
        raise NonexistentUser, "'#{username}' does not exist"
      end

      logger.debug '-> %s %s %d (%.3f s)' % [url, 'GET', response.status, duration]

      data = JSON.parse(response.body)
      User.new(data['name'], data['location'], data['public_repos'])
    end

    def public_repos_for_user(username)
      headers = { 'Authorization' => "token #{token}" }
      url = "https://api.github.com/users/#{username}/repos"

      response = connection.get(url, nil, headers)

      if !VALID_STATUS_CODES.include?(response.status)
        raise RequestFailure, JSON.parse(response.body)['message']
      end

      if response.status == 404
        raise NonexistentUser, "'#{username}' does not exist"
      end

      if response.status == 401
        raise AuthenticationFailure, "Authentication failed, please set the Github authentication token to a valid Github access token"
      end


      data = JSON.parse(response.body)
      data.map { |repo| Repository.new(repo['full_name'], repo['html_url']) }
    end

    def connection
      @connection ||= Faraday::Connection.new do |builder|
        builder.use Middleware::Logging
        builder.adapter Faraday.default_adapter
      end
    end
  end
end
