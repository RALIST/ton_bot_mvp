require 'rake'
require 'active_record'
require_relative 'config/environment'

include ActiveRecord::Tasks

root = File.expand_path '..', __FILE__
DatabaseTasks.env = ENV['ENV'] || 'development'
DatabaseTasks.database_configuration = YAML.safe_load(File.read(File.join(root, 'config/database.yml')), aliases: true)
DatabaseTasks.db_dir = File.join root, 'db'
DatabaseTasks.fixtures_path = File.join root, 'test/fixtures'
DatabaseTasks.migrations_paths = [File.join(root, 'db/migrate')]
DatabaseTasks.root = root

task :environment do
  ActiveRecord::Base.configurations = DatabaseTasks.database_configuration
  ActiveRecord::Base.establish_connection DatabaseTasks.env.to_sym
end

load 'active_record/railties/databases.rake'

namespace :scraper do
  desc 'Show failed scrapes stats'
  task :failed_stats => :environment do
    puts "\nFailed Scrapes by Source:"
    TonBot::Scrapers::ScraperManager.sources.each do |source|
      total = FailedScrape.by_source(source).count
      retryable = FailedScrape.retryable.by_source(source).count
      puts "#{source}: #{total} total, #{retryable} retryable"
    end
  end

  desc 'Clear all failed scrapes'
  task :clear_failed => :environment do
    count = FailedScrape.delete_all
    puts "Cleared #{count} failed scrapes"
  end

  desc 'Retry failed scrapes now'
  task :retry_failed => :environment do
    puts "Enqueueing retry job for failed scrapes..."
    TonBot::RetryFailedScrapesJob.perform_async
    puts "Retry job enqueued"
  end

  desc 'Show failed scrape details'
  task :show_failed => :environment do
    FailedScrape.find_each do |scrape|
      puts "\nURL: #{scrape.url}"
      puts "Source: #{scrape.source}"
      puts "Retries: #{scrape.retry_count}"
      puts "Last Retry: #{scrape.last_retry_at}"
      puts "Error: #{scrape.error}"
      puts "-" * 50
    end
  end
end

# Add default rake task
task :default => 'db:stats'
