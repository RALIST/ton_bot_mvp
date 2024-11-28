require 'sidekiq'
require 'sidekiq/web'
require_relative 'environment'

# Load Sidekiq configuration from YAML
sidekiq_config = YAML.safe_load(
  ERB.new(File.read('config/sidekiq.yml')).result,
  aliases: true
)[ENV['RACK_ENV'] || 'development']

Sidekiq.configure_server do |config|
  config.redis = { url: ENV['REDIS_URL'] }
  
  # Set up ActiveRecord connection pool for Sidekiq server
  database_config = ActiveRecord::Base.configurations[ENV['RACK_ENV'] || 'development']
  database_config['pool'] = sidekiq_config['concurrency'] if sidekiq_config['concurrency']
  ActiveRecord::Base.establish_connection(database_config)
  
  # Apply configuration from YAML
  config.options.merge!(sidekiq_config.transform_keys(&:to_sym))
end

Sidekiq.configure_client do |config|
  config.redis = { url: ENV['REDIS_URL'] }
end

# Enable Sidekiq Web UI
Sidekiq::Web.use(Rack::Auth::Basic) do |username, password|
  username == ENV.fetch('ADMIN_USERNAME', 'admin') && 
  password == ENV.fetch('ADMIN_TOKEN', 'admin')
end
