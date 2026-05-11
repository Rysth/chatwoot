#!/bin/bash
set -e

echo "========================================"
echo "Chatwoot Docker Local Setup Script"
echo "========================================"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Step 1: Check if .env exists, if not create from example
if [ ! -f .env ]; then
  echo -e "${YELLOW}Step 1: Creating .env file...${NC}"
  if [ ! -f .env.example ]; then
    echo -e "${RED}Error: .env.example not found!${NC}"
    exit 1
  fi

  cp .env.example .env

  # Generate SECRET_KEY_BASE
  SECRET_KEY=$(openssl rand -hex 64)
  sed -i "s/SECRET_KEY_BASE=.*/SECRET_KEY_BASE=${SECRET_KEY}/" .env

  # Set development defaults for docker-compose
  sed -i 's/^POSTGRES_HOST=.*/POSTGRES_HOST=postgres/' .env
  sed -i 's/^POSTGRES_USERNAME=.*/POSTGRES_USERNAME=postgres/' .env
  sed -i 's/^POSTGRES_PASSWORD=.*/POSTGRES_PASSWORD=postgres/' .env
  sed -i 's/^REDIS_URL=.*/REDIS_URL=redis:\/\/redis:6379/' .env
  sed -i 's/^REDIS_PASSWORD=.*/REDIS_PASSWORD=/' .env
  sed -i 's/^RAILS_ENV=.*/RAILS_ENV=development/' .env
  sed -i 's/^SMTP_ADDRESS=.*/SMTP_ADDRESS=mailhog/' .env
  sed -i 's/^SMTP_PORT=.*/SMTP_PORT=1025/' .env

  echo -e "${GREEN}.env file created and configured.${NC}"
else
  echo -e "${GREEN}Step 1: .env file already exists, skipping...${NC}"
fi

# Step 1.5: Ensure docker-compose has postgres auth method set
if ! grep -q "POSTGRES_HOST_AUTH_METHOD=trust" docker-compose.yaml; then
  echo -e "${YELLOW}Step 1.5: Adding PostgreSQL auth config to docker-compose.yaml...${NC}"
  sed -i 's/POSTGRES_PASSWORD=$/POSTGRES_PASSWORD=postgres\n      - POSTGRES_HOST_AUTH_METHOD=trust/' docker-compose.yaml
  echo -e "${GREEN}PostgreSQL auth config added.${NC}"
fi

# Step 2: Clean up previous containers and volumes
echo -e "${YELLOW}Step 2: Cleaning up previous Docker containers and volumes...${NC}"
docker compose down -v --remove-orphans || true
echo -e "${GREEN}Cleanup complete.${NC}"

# Step 3: Build base image first, then dependent services
echo -e "${YELLOW}Step 3: Building base Docker image...${NC}"
docker compose build base

echo -e "${YELLOW}Step 3b: Building dependent services...${NC}"
docker compose build rails sidekiq vite

echo -e "${YELLOW}Step 3c: Starting Docker services...${NC}"
docker compose up -d

# Step 4: Wait for services to be healthy
echo -e "${YELLOW}Step 4: Waiting for services to be ready...${NC}"
sleep 15

# Wait for postgres specifically
echo "Waiting for PostgreSQL..."
until docker compose exec -T postgres pg_isready -U postgres > /dev/null 2>&1; do
  echo "PostgreSQL is not ready yet, waiting..."
  sleep 3
done
echo -e "${GREEN}PostgreSQL is ready!${NC}"

# Step 5: Prepare database
echo -e "${YELLOW}Step 5: Preparing database (schema, seeds, migrations)...${NC}"
docker compose exec -T rails bundle exec rails db:chatwoot_prepare
echo -e "${GREEN}Database prepared successfully!${NC}"

# Step 6: Verify branding
echo -e "${YELLOW}Step 6: Verifying installation configuration...${NC}"
docker compose exec -T rails bundle exec rails runner "
  config = InstallationConfig.find_by(name: 'INSTALLATION_NAME')
  if config
    puts \"✓ INSTALLATION_NAME: #{config.value}\"
  else
    puts \"✗ INSTALLATION_NAME not found!\"
    exit 1
  end

  brand = InstallationConfig.find_by(name: 'BRAND_NAME')
  if brand
    puts \"✓ BRAND_NAME: #{brand.value}\"
  end

  logo = InstallationConfig.find_by(name: 'LOGO')
  if logo
    puts \"✓ LOGO: #{logo.value}\"
  end
"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Setup complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Your Chatwoot instance is now running at:"
echo "  - Application: http://localhost:3000"
echo "  - MailHog:     http://localhost:8025"
echo ""
echo "Useful commands:"
echo "  docker compose logs -f rails    # View Rails logs"
echo "  docker compose logs -f sidekiq  # View Sidekiq logs"
echo "  docker compose logs -f vite     # View Vite logs"
echo "  docker compose exec rails bundle exec rails console  # Rails console"
echo ""
