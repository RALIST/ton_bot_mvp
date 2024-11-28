require 'bundler/setup'
Bundler.require(:default, ENV['RACK_ENV'] || 'development')

# Initialize ActiveRecord
require 'sinatra/activerecord'

# Load environment variables
require 'dotenv'
Dotenv.load

# Load Sidekiq and its web interface
require 'sidekiq'
require 'sidekiq/web'

# Set up database connection
database_config = YAML.safe_load(
  ERB.new(File.read('config/database.yml')).result,
  aliases: true
)[ENV['RACK_ENV'] || 'development']

ActiveRecord::Base.establish_connection(database_config)

# Load all models
Dir[File.join(__dir__, '../lib/models', '*.rb')].each { |file| require file }

# Load all scrapers
Dir[File.join(__dir__, '../lib/scrapers', '*.rb')].each { |file| require file }

# Load all jobs
Dir[File.join(__dir__, '../lib/jobs', '*.rb')].each { |file| require file }

# Load initializers
Dir[File.join(__dir__, 'initializers', '*.rb')].each { |file| require file }

# Load main application files
require_relative '../lib/bot'
require_relative '../lib/embeddings'
require_relative '../lib/admin_app'
