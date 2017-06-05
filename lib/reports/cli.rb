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
    def repositories(username)
      puts "\nFetching repositories for #{username}"

      repositories = client.public_repos_for_user(username)

      puts "#{username} has #{repositories.size} public repos.\n\n"
      repositories.each { |repo| puts "#{repo.name} - #{repo.url}" }
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
  end
end
