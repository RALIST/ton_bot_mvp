module TonBot
  module Scrapers
    class ScraperManager
      def initialize
        @scrapers = [
          TonScraper.new,
          TactScraper.new
        ]
      end

      def scrape_all
        @scrapers.each do |scraper|
          puts "\nStarting scraper: #{scraper.class.name}"
          scraper.scrape_all
        end

        # Schedule retry job for any failed scrapes
        schedule_retry_job
      end

      def self.sources
        ['ton_docs', 'tact_docs']
      end

      private

      def schedule_retry_job
        failed_count = FailedScrape.retryable.count
        if failed_count > 0
          puts "Scheduling retry job for #{failed_count} failed scrapes"
          RetryFailedScrapesJob.perform_in(30.minutes)
        end
      end
    end
  end
end
