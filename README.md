# TON Blockchain AI Bot MVP

A Ruby-based implementation of an AI bot that provides information about the TON blockchain using RAG (Retrieval Augmented Generation) with Claude 3.5 Sonnet.

## Features

- Web scraping of ton.org documentation
- Vector embeddings for efficient information retrieval
- Claude 3.5 Sonnet for accurate responses
- Redis caching for performance
- Simple REST API interface

## Prerequisites

- Anthropic API key

For traditional setup:

- Ruby 3.3.0
- PostgreSQL with pgvector extension
- Redis

For Docker setup:

- Docker
- Docker Compose

## Environment Setup (Important!)

1. Copy the example environment file:

```bash
cp .env.example .env
```

2. Edit .env with your configuration:

```bash
# Required API Keys
ANTHROPIC_API_KEY=your_claude_api_key_here  # Required for embeddings generation
ADMIN_TOKEN=your_admin_token_here           # Required for content refresh

# Database Configuration (Docker defaults)
DB_HOST=db                  # Use 'db' for Docker, 'localhost' for traditional setup
DB_PORT=5432
DB_NAME=ton_bot
DB_USER=postgres
DB_PASSWORD=postgres

# Redis Configuration (Docker defaults)
REDIS_URL=redis://redis:6379/0  # Use this URL for Docker setup

# Server Configuration
PORT=4567
RACK_ENV=development
```

Note: When using Docker, the DB_HOST and REDIS_URL are preconfigured to use the Docker service names. Do not change these values unless you're using the traditional setup.

## Docker Setup

1. Ensure your .env file is properly configured (see Environment Setup above)

2. Build and start the services:

```bash
docker-compose up -d
```

3. Set up the database (first time only):

```bash
docker-compose exec app bundle exec ruby setup.rb
```

4. Initial content scraping:

```bash
curl -X POST http://localhost:4567/refresh \
  -H "Authorization: Bearer your_admin_token" \
  -H "Content-Type: application/json"
```

The application will be available at http://localhost:4567

To stop the services:

```bash
docker-compose down
```

To view logs:

```bash
docker-compose logs -f
```

## Traditional Setup

1. Install dependencies:

```bash
bundle install
```

2. Set up environment variables (see Environment Setup above, but use localhost for DB_HOST)

3. Set up the database:

```bash
createdb ton_bot
psql ton_bot -c 'CREATE EXTENSION vector;'
```

4. Initial content scraping:

```bash
curl -X POST http://localhost:4567/refresh \
  -H "Authorization: Bearer your_admin_token" \
  -H "Content-Type: application/json"
```

## Running the Server

With Docker:

```bash
docker-compose up -d
```

Traditional:

```bash
bundle exec puma
```

## API Usage

### Ask a Question

```bash
curl -X POST http://localhost:4567/ask \
  -H "Content-Type: application/json" \
  -d '{"question": "What is TON blockchain?"}'
```

Response format:

```json
{
  "answer": "Detailed answer about TON blockchain...",
  "sources": [
    "https://ton.org/learn/ton-concept",
    "https://ton.org/learn/decentralized-network"
  ],
  "timestamp": "2024-03-15T10:30:00Z"
}
```

### Refresh Content (Admin Only)

```bash
curl -X POST http://localhost:4567/refresh \
  -H "Authorization: Bearer your_admin_token" \
  -H "Content-Type: application/json"
```

## Architecture

### Components

1. **Scraper (`lib/scraper.rb`)**

   - Handles web scraping of ton.org
   - Processes and cleans HTML content
   - Extracts relevant information

2. **Embeddings (`lib/embeddings.rb`)**

   - Manages vector embeddings
   - Handles database operations
   - Implements similarity search

3. **Bot (`lib/bot.rb`)**

   - Integrates with Claude 3.5 Sonnet
   - Manages response generation
   - Handles caching

4. **API (`config.ru`)**
   - Provides REST endpoints
   - Handles request/response
   - Implements basic auth

## Database Schema

```sql
CREATE TABLE embeddings (
  id SERIAL PRIMARY KEY,
  embedding vector(1536),
  content TEXT,
  document_id TEXT,
  section TEXT,
  url TEXT,
  metadata JSONB,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

## Caching Strategy

- Redis is used for caching responses
- Default TTL: 1 hour
- Cache key format: `ton_bot:{normalized_question}`

## Error Handling

The API returns appropriate HTTP status codes:

- 200: Successful response
- 400: Invalid request
- 401: Unauthorized
- 500: Server error

## Troubleshooting

### Docker Issues

1. Environment Variables:

   - Ensure .env file exists and is properly configured
   - Check if DB_HOST is set to 'db' for Docker setup
   - Verify REDIS_URL points to the Redis container

2. Database Connection:

   - Check logs: `docker-compose logs db`
   - Verify connection: `docker-compose exec db psql -U postgres -d ton_bot -c "\dt"`

3. Redis Connection:

   - Check Redis: `docker-compose exec redis redis-cli ping`

4. Application Logs:
   - View all logs: `docker-compose logs -f`
   - App specific: `docker-compose logs app`

## Future Improvements

1. **Content Updates**

   - Implement periodic content refresh
   - Add diff-based updates
   - Track content changes

2. **Performance**

   - Implement batch processing
   - Optimize embedding generation
   - Add query result caching

3. **Features**

   - Add conversation history
   - Implement streaming responses
   - Add source content preview

4. **Monitoring**
   - Add request logging
   - Implement error tracking
   - Add performance metrics

## Contributing

1. Fork the repository
2. Create your feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## License

MIT License
