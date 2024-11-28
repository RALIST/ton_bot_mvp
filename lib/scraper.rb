require_relative 'scrapers/base_scraper'
require_relative 'scrapers/ton_scraper'
require_relative 'scrapers/tact_scraper'
require_relative 'scrapers/scraper_manager'

module TonBot
  # Maintain backward compatibility by delegating to ScraperManager
  class Scraper
    def self.new
      Scrapers::ScraperManager.new
    end
  end
end
