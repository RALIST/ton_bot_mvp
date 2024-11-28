# Puma configuration file

# Number of workers (processes)
workers ENV.fetch('WEB_CONCURRENCY', 2).to_i

# Min and max threads per worker
max_threads = ENV.fetch('MAX_THREADS', 5).to_i
min_threads = ENV.fetch('MIN_THREADS', max_threads).to_i
threads min_threads, max_threads

# Set up socket location
bind 'tcp://0.0.0.0:4567'

# Environment
environment ENV.fetch('RACK_ENV', 'development')

# Allow puma to be restarted by `touch tmp/restart.txt`
plugin :tmp_restart

# Preload app (recommended for memory efficiency)
preload_app!

# Log settings
stdout_redirect '/dev/stdout', '/dev/stderr', true if ENV['RACK_ENV'] == 'production'
