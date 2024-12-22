require 'sidekiq'

module TonBot
  class RetryFailedScrapesJob
    include Sidekiq::Job

    sidekiq_options queue: :scraping, retry: 0

    def perform
      # Process each source separately to maintain proper scraping context
      TonBot::Scrapers::ScraperManager.sources.each do |source|
        retry_source_scrapes(source)
      end
    end

    private

    def retry_source_scrapes(source)
      failed_scrapes = FailedScrape.retryable.by_source(source)
      return if failed_scrapes.empty?

      puts "Retrying #{failed_scrapes.count} failed scrapes for #{source}"

      # Create appropriate scraper for the source
      scraper = case source
                when 'ton_docs'
                  TonBot::Scrapers::TonScraper.new
                when 'tact_docs'
                  TonBot::Scrapers::TactScraper.new
                else
                  puts "Unknown source: #{source}"
                  return
                end

      failed_scrapes.each do |failed_scrape|
        begin
          puts "Retrying scrape for #{failed_scrape.url}"
          scraper.retry_scrape(failed_scrape)
        rescue StandardError => e
          puts "Error retrying scrape for #{failed_scrape.url}: #{e.message}"
        end
      end
    end
  end
end
