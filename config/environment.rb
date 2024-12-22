require 'bundler/setup'
Bundler.require(:default, ENV['RACK_ENV'] || 'development')

# Load environment variables
require 'dotenv'
Dotenv.load

# Load Sidekiq and its web interface
require 'sidekiq'
require 'sidekiq/web'

# Load all models
Dir[File.join(__dir__, '../lib/models', '*.rb')].sort.each { |file| require file }

# Load all scrapers
Dir[File.join(__dir__, '../lib/scrapers', '*.rb')].sort.each { |file| require file }

# Load all jobs
Dir[File.join(__dir__, '../lib/jobs', '*.rb')].sort.each { |file| require file }

# Load initializers
Dir[File.join(__dir__, 'initializers', '*.rb')].sort.each { |file| require file }

# Load main application files
require_relative '../lib/bot'
require_relative '../lib/embeddings'
require_relative '../lib/admin_app'
