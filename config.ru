require 'sinatra'
require 'json'
require 'dotenv'
require 'anthropic'
require 'openai'
require 'sidekiq/web'
require_relative 'lib/scraper'
require_relative 'lib/admin_app'

Dotenv.load if File.exist?('.env')

# Load initializers
require_relative 'config/initializers/anthropic'
require_relative 'config/initializers/openai'

require_relative 'lib/embeddings'
require_relative 'lib/bot'

class TonBotAPI < Sinatra::Base
  configure do
    set :bot, TonBot::Bot.new
  end

  before do
    content_type :json
  end

  # Health check endpoint with environment info
  get '/health' do
    {
      status: 'ok',
      timestamp: Time.now.utc.iso8601,
    }.to_json
  end

  # Ask a question
  post '/ask' do
    request_payload = JSON.parse(request.body.read)
    question = request_payload['question']

    halt 400, { error: 'Question is required' }.to_json unless question

    response = settings.bot.answer_question(question)
    response.to_json
  rescue StandardError => e
    status 500
    { error: "Failed to generate response: #{e.message}" }.to_json
  end

  # Refresh content (admin only)
  post '/refresh' do
    halt 401, { error: 'Unauthorized' }.to_json unless authorized?
    scraper = TonBot::Scraper.new
    documents = scraper.scrape_all

    {
      status: 'success',
      documents_processed: documents.length,
      timestamp: Time.now.utc.iso8601
    }.to_json
  rescue StandardError => e
    status 500
    { error: e.message }.to_json
  end

  private

  def authorized?
    # auth_token = request.env['HTTP_AUTHORIZATION']&.split(' ')&.last
    # auth_token == ENV['ADMIN_TOKEN']
    true
  end
end

# Protect Sidekiq web interface with admin authentication
Sidekiq::Web.use(Rack::Auth::Basic) do |username, password|
  username == 'admin' && password == ENV['ADMIN_TOKEN']
end

# Create a new Rack builder instance
app = Rack::Builder.new do
  # Mount the main API at root
  map '/' do
    run TonBotAPI
  end

  # Mount the admin interface at /admin
  map '/admin' do
    run TonBot::AdminApp
  end

  # Mount Sidekiq web interface at /sidekiq
  map '/sidekiq' do
    run Sidekiq::Web
  end
end

# Run the combined application
run app
