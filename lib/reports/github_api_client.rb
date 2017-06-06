require 'faraday'
require_relative 'middleware/authentication'
require_relative 'middleware/logging'
require_relative 'middleware/status_check'
require_relative 'middleware/json_parsing'
require_relative 'middleware/cache'
require_relative 'storage/redis'

module Reports
  class Error < StandardError; end
  class NonexistentUser < Error; end
  class RequestFailure < Error; end
  class AuthenticationFailure < Error; end
  class ConfigurationFailure < Error; end
  class GistCreationFailure < Error; end

  User = Struct.new(:name, :location, :public_repos_count)
  Repository = Struct.new(:name, :url, :languages)
  ActivityEvent = Struct.new(:type, :repo_name)

  class GitHubAPIClient
    def user_info(username)
      url = "https://api.github.com/users/#{username}"

      response = connection.get(url)
      raise NonexistentUser, "'#{username}' does not exist" if response.status == 404

      data = response.body
      User.new(data['name'], data['location'], data['public_repos'])
    end

    def public_repos_for_user(username, options)
      url = "https://api.github.com/users/#{username}/repos"

      response = connection.get(url)
      raise NonexistentUser, "'#{username}' does not exist" if response.status == 404

      repositories = response.body
      link_header = response.headers['link']

      fetch_next_pages(link_header, repositories)

      repositories.map do |repo|
        next if !options[:forks] && repo['fork']

        repo_name = repo['full_name']
        repo_languages = connection.get("https://api.github.com/repos/#{repo_name}/languages").body
        Repository.new(repo_name, repo['html_url'], repo_languages)
      end.compact
    end

    def public_events_for_user(username)
      url = "https://api.github.com/users/#{username}/events/public"

      response = connection.get(url)
      raise NonexistentUser, "'#{username}' does not exist" if response.status == 404

      events = response.body
      link_header = response.headers['link']

      fetch_next_pages(link_header, events)

      events.map { |event| ActivityEvent.new(event['type'], event['repo']['name']) }
    end

    def create_private_gist(description, filename, contents)
      url = 'https://api.github.com/gists'
      payload = JSON.dump({
        description: description,
        files: {
          filename => {
            content: contents
          }
        }
      })

      response = connection.post(url, payload)
      raise GistCreationFailure, response.body['message'] unless response.status == 201

      response.body['html_url']
    end

    def repo_starred?(repo_name)
      url = "https://api.github.com/user/starred/#{repo_name}"
      response = connection.get(url)
      response.status == 204
    end

    def star_repo(repo_name)
      url = "https://api.github.com/user/starred/#{repo_name}"
      response = connection.put(url)
      raise RequestFailure, response.body['message'] unless response.status == 204
    end

    def unstar_repo(repo_name)
      url = "https://api.github.com/user/starred/#{repo_name}"
      response = connection.delete(url)
      raise RequestFailure, response.body['message'] unless response.status == 204
    end

    private

    def connection
      @connection ||= Faraday::Connection.new do |builder|
        builder.use Middleware::JSONParsing
        builder.use Middleware::StatusCheck
        builder.use Middleware::Authentication
        builder.use Middleware::Logging
        builder.use Middleware::Cache, Storage::RedisWrapper.new
        builder.adapter Faraday.default_adapter
      end
    end

    def fetch_next_pages(link_header, items)
      if link_header
        while match_data = link_header.match(/<(.*)>; rel="next"/)
          next_page_url = match_data[1]
          response = connection.get(next_page_url)
          link_header = response.headers['link']
          items += response.body
        end
      end
    end
  end
end
