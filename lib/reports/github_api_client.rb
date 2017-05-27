require 'faraday'
require 'json'
require 'logger'


module Reports
  class Error < StandardError; end
  class NonexistentUser < Error; end
  class RequestFailure < Error; end
  class AuthenticationFailure < Error; end

  User = Struct.new(:name, :location, :public_repos_count)

  VALID_STATUS_CODES = [200, 302, 401, 403, 404, 422]

  class GitHubAPIClient
    attr_reader :logger, :token


    def initialize(token)
      @logger = Logger.new(STDOUT)
      @logger.formatter = proc { |serverity, time, progname, msg| msg + "\n" }
      @token = token
    end

    def user_info(username)
      headers = { 'Authorization' => "token #{token}" }
      url = "https://api.github.com/users/#{username}"

      start_time = Time.now
      response = Faraday.new.get(url, nil, headers)

      duration = Time.now - start_time

      if !VALID_STATUS_CODES.include?(response.status)
        raise RequestFailure, JSON.parse(response.body)['message']
      elsif response.status == 404
        raise NonexistentUser, "'#{username}' does not exist"
      elsif response.status == 401
        raise AuthenticationFailure, "Authentication failed, please set the Github authentication token to a valid Github access token"
      end

      logger.debug '-> %s %s %d (%.3f s)' % [url, 'GET', response.status, duration]

      data = JSON.parse(response.body)
      User.new(data['name'], data['location'], data['public_repos'])
    end
  end

end
