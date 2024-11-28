# Используем образ Ruby с нужной версией
FROM ruby:3.3.0-slim

RUN dpkg --add-architecture arm64 && apt update && apt install -y \
    nodejs \
    openssl \
    git \
    libpq-dev \
    build-essential

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

# Expose port
EXPOSE 4567

# Start the application with Puma
CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]
