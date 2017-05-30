require 'rubygems'
require 'bundler/setup'
require 'thor'

require 'reports/github_api_client'
require 'reports/table_printer'

require 'dotenv'
Dotenv.load

module Reports

  class CLI < Thor

    desc 'console', 'Open an RB session with all dependencies loaded and API defined.'
    def console
      require 'irb'
      ARGV.clear
      IRB.start
    end

    desc 'user_info USERNAME', 'Get information for a user'
    def user_info(username)
      puts "Getting info for #{username}"

      user = client.user_info(username)

      puts "name: #{user.name}"
      puts "location: #{user.location}"
      puts "public repos: #{user.public_repos_count}"
    rescue Error => error
      puts "ERROR: #{error.message}"
    end

    desc 'repositories USERNAME', 'Get repositories information for a user'
    def repositories(username)
      puts "Fetching repositories for #{username}"

      repositories = client.public_repos_for_user(username)

      puts "#{username} has #{repositories.size} public repos.\n\n"
      repositories.each { |repo| puts "#{repo.name} - #{repo.url}" }
    rescue Error => error
      puts "ERROR: #{error.message}"
    end

    private

    def client
      @client ||= Reports::GitHubAPIClient.new(ENV['GITHUB_TOKEN'])
    end
  end
end
