require_relative 'config/environment'

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
    scraper = TonBot::Scrapers::ScraperManager.new
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

# Create a new Rack builder instance
app = Rack::Builder.new do
  # Enable CORS
  use Rack::Cors do
    allow do
      origins '*'
      resource '*', headers: :any, methods: [:get, :post, :options]
    end
  end

  # Mount Sidekiq web interface at /sidekiq with authentication
  map '/sidekiq' do
    use Rack::Auth::Basic, "Protected Area" do |username, password|
      # Secure the Sidekiq dashboard with basic auth
      username == ENV.fetch('ADMIN_USERNAME', 'admin') && 
      password == ENV.fetch('ADMIN_TOKEN', 'admin')
    end

    run Sidekiq::Web
  end

  # Mount the admin interface at /admin
  map '/admin' do
    run TonBot::AdminApp
  end

  # Mount the main API at root
  map '/' do
    run TonBotAPI
  end
end

# Run the combined application
run app
