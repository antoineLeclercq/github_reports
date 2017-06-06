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
      puts "\nGetting info for #{username}"

      user = client.user_info(username)

      puts "name: #{user.name}"
      puts "location: #{user.location}"
      puts "public repos: #{user.public_repos_count}"
    rescue Error => error
      puts "ERROR: #{error.message}"
    end

    desc 'repositories USERNAME', 'Get repositories information for a user'
    option :forks, type: :boolean, desc: 'Include forks in stats', default: false
    def repositories(username)
      puts "\nFetching repositories for #{username}"

      repositories = client.public_repos_for_user(username, forks: options[:forks])

      puts "#{username} has #{repositories.size} public repos.\n\n"
      print_repos_report(repositories)
    rescue Error => error
      puts "ERROR: #{error.message}"
    end

    desc 'activity USERNAME', 'Get public activity information for a user'
    def activity(username)
      puts "\nFetching activity for #{username}"

      activity_events = client.public_events_for_user(username)

      print_activity_report(activity_events)
    rescue Error => error
      puts "ERROR: #{error.message}"
    end

    desc "gist DESCRIPTION FILENAME CONTENTS", "Create a private Gist on GitHub"
    def gist(description, filename, contents)
      puts "Creating a private Gist..."

      gist_url = client.create_private_gist(description, filename, contents)

      puts "Your Gist is available at #{gist_url}."
    rescue Error => error
      require 'pry'; binding.pry
      puts "ERROR #{error.message}"
      exit 1
    end

    desc "star_repo FULL_REPO_NAME", "Star a repository"
    def star_repo(repo_name)
      puts "Starring #{repo_name}..."

      if client.repo_starred?(repo_name)
        puts "You have already starred #{repo_name}."
      else
        client.star_repo(repo_name)
        puts "You have starred #{repo_name}."
      end
    rescue Error => error
      puts "ERROR #{error.message}"
      exit 1
    end

    desc "unstar_repo FULL_REPO_NAME", "Unstar a repository"
    def unstar_repo(repo_name)
      puts "Unstarring #{repo_name}..."

      client = GitHubAPIClient.new

      if client.repo_starred?(repo_name)
        client.unstar_repo(repo_name)
        puts "You have unstarred #{repo_name}."
      else
        puts "You have not starred #{repo_name}."
      end
    rescue Error => error
      puts "ERROR #{error.message}"
      exit 1
    end

    private

    def client
      @client ||= Reports::GitHubAPIClient.new
    end

    def print_activity_report(events)
      table_printer = TablePrinter.new(STDOUT)
      event_types_map = events.each_with_object(Hash.new(0)) do |event, counts|
        counts[event.type] += 1
      end

      table_printer.print(event_types_map, title: "Event Summary", total: true)
      push_events = events.select { |event| event.type == "PushEvent" }
      push_events_map = push_events.each_with_object(Hash.new(0)) do |event, counts|
        counts[event.repo_name] += 1
      end

      puts # blank line
      table_printer.print(push_events_map, title: "Project Push Summary", total: true)
    end

    def print_repos_report(repos)
      table_printer = TablePrinter.new(STDOUT)

      repos.each do |repo|
        table_printer.print(repo.languages, title: repo.name, humanize: true)
        puts # blank line
      end

      stats = Hash.new(0)
      repos.each do |repo|
        repo.languages.each_pair do |language, bytes|
          stats[language] += bytes
        end
      end

      table_printer.print(stats, title: "Language Summary", humanize: true, total: true)
    end
  end
end
