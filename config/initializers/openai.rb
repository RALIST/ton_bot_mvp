require 'openai'
require 'dotenv'

# Load environment variables if not already loaded
Dotenv.load if File.exist?('.env') && !ENV['OPENAI_API_KEY']

OpenAI.configure do |config|
  config.access_token = ENV['OPENAI_API_KEY']
  config.organization_id = ENV['OPENAI_ORGANIZATION_ID'] # Optional
end
