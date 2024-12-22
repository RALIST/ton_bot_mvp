require_relative 'environment'

Sidekiq.configure_server do |config|
  config.redis = { url: ENV['REDIS_URL'] }
  config.options.merge!(sidekiq_config.transform_keys(&:to_sym))
end

Sidekiq.configure_client do |config|
  config.redis = { url: ENV['REDIS_URL'] }
end
