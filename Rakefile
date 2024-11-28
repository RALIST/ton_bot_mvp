require 'sinatra/activerecord/rake'
require 'rake'
require_relative 'lib/scraper'
require_relative 'lib/bot'
require_relative 'lib/admin_app'

namespace :db do
  task :load_config do
    require './lib/admin_app'
  end
end

namespace :ton do
  desc "Scrape TON documentation"
  task :scrape do
    puts "Starting documentation scraping..."
    scraper = TonBot::Scraper.new
    scraper.scrape_all
    puts "Scraping completed"
  end

  desc "Process unprocessed documents"
  task :process_documents do
    puts "Processing unprocessed documents..."
    scraper = TonBot::Scraper.new
    scraper.process_unprocessed_documents
    puts "Processing queued"
  end

  desc "Clear all embeddings and reset document processing status"
  task :reset_embeddings do
    require 'pg'
    conn = PG.connect(
      host: ENV['DB_HOST'],
      port: ENV['DB_PORT'],
      dbname: ENV['DB_NAME'],
      user: ENV['DB_USER'],
      password: ENV['DB_PASSWORD']
    )

    puts "Clearing embeddings..."
    conn.exec('TRUNCATE TABLE embeddings')
    conn.exec('UPDATE raw_documents SET processed = false')
    puts "Embeddings cleared and documents reset"
  end

  desc "Show system status"
  task :status do
    require 'pg'
    conn = PG.connect(
      host: ENV['DB_HOST'],
      port: ENV['DB_PORT'],
      dbname: ENV['DB_NAME'],
      user: ENV['DB_USER'],
      password: ENV['DB_PASSWORD']
    )

    total_docs = conn.exec('SELECT COUNT(*) FROM raw_documents').getvalue(0,0)
    processed_docs = conn.exec('SELECT COUNT(*) FROM raw_documents WHERE processed = true').getvalue(0,0)
    total_embeddings = conn.exec('SELECT COUNT(*) FROM embeddings').getvalue(0,0)
    
    puts "\nSystem Status:"
    puts "-------------"
    puts "Total Documents: #{total_docs}"
    puts "Processed Documents: #{processed_docs}"
    puts "Total Embeddings: #{total_embeddings}"
    
    if defined?(Sidekiq::Stats)
      stats = Sidekiq::Stats.new
      puts "\nSidekiq Status:"
      puts "--------------"
      puts "Processed Jobs: #{stats.processed}"
      puts "Failed Jobs: #{stats.failed}"
      puts "Enqueued Jobs: #{stats.enqueued}"
    end
  end

  desc "Health check"
  task :health do
    require 'net/http'
    require 'json'
    
    uri = URI('http://localhost:4567/health')
    response = Net::HTTP.get_response(uri)
    
    if response.is_a?(Net::HTTPSuccess)
      data = JSON.parse(response.body)
      puts "API Status: #{data['status']}"
      puts "Timestamp: #{data['timestamp']}"
    else
      puts "Error: API not responding"
    end
  end
end

# Default task shows available commands
task :default do
  puts "\nAvailable commands:"
  puts "----------------"
  puts "rake db:migrate              # Run database migrations"
  puts "rake db:rollback            # Rollback last migration"
  puts "rake ton:scrape             # Scrape TON documentation"
  puts "rake ton:process_documents  # Process unprocessed documents"
  puts "rake ton:reset_embeddings   # Clear embeddings and reset processing status"
  puts "rake ton:status            # Show system status"
  puts "rake ton:health            # Check API health"
end
