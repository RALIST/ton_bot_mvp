require 'sidekiq'
# Load initializers
require_relative 'initializers/anthropic'
require_relative 'initializers/openai'


Sidekiq.configure_server do |config|
  config.redis = { url: ENV['REDIS_URL'] }
  config.queues = %w[embeddings default]
end

Sidekiq.configure_client do |config|
  config.redis = { url: ENV['REDIS_URL'] }
end
