require 'anthropic'
require 'dotenv'

# Load environment variables if not already loaded
Dotenv.load if File.exist?('.env') && !ENV['ANTHROPIC_API_KEY']

# Configure Anthropic globally
Anthropic.configure do |config|
  config.access_token = ENV['ANTHROPIC_API_KEY']
end
