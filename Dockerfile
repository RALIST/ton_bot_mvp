# Используем образ Ruby с нужной версией
FROM ruby:3.3.0-slim

RUN dpkg --add-architecture arm64 && apt update && apt install -y \
    nodejs \
    openssl \
    git \
    libpq-dev \
    build-essential \
    postgresql-client

# Устанавливаем рабочую директорию внутри контейнера
WORKDIR /app

# Копируем Gemfile и Gemfile.lock в контейнер
COPY Gemfile Gemfile.lock ./

# Устанавливаем гемы
RUN gem cleanup && \
    gem install bundler && \
    bundle install --jobs 20 --retry 5

# Копируем остальные файлы проекта в контейнер
COPY . .

# Create necessary directories
RUN mkdir -p tmp/pids log

# Expose port
EXPOSE 4567

# Prepare database and run migrations
RUN bundle exec rake db:prepare
RUN bundle exec rake db:migrate

# Start the application with Puma
CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]
