#!/bin/bash
set -e

echo "========================================"
echo "Chatwoot Upstream Sync Script"
echo "========================================"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
UPSTREAM_URL="https://github.com/chatwoot/chatwoot.git"
CLIENT_BRANCH="${1:-client/rysth-design}"

# Step 1: Ensure upstream remote exists
echo -e "${YELLOW}Step 1: Configuring upstream remote...${NC}"
if ! git remote | grep -q "upstream"; then
  git remote add upstream "$UPSTREAM_URL"
  echo -e "${GREEN}Upstream remote added.${NC}"
else
  echo -e "${GREEN}Upstream remote already exists.${NC}"
fi

# Step 2: Fetch upstream
echo -e "${YELLOW}Step 2: Fetching upstream...${NC}"
git fetch upstream develop
echo -e "${GREEN}Upstream fetched.${NC}"

# Step 3: Sync develop with upstream
echo -e "${YELLOW}Step 3: Syncing develop with upstream/develop...${NC}"
git checkout develop

# Check for uncommitted changes
if [ -n "$(git status --porcelain)" ]; then
  echo -e "${RED}Error: You have uncommitted changes. Please commit or stash them first.${NC}"
  exit 1
fi

git merge upstream/develop --no-edit 2>&1 || {
  echo -e "${YELLOW}Merge conflicts detected in db/schema.rb, resolving...${NC}"
  # Auto-resolve schema.rb conflicts (always take upstream version)
  CONFLICTED_FILES=$(git diff --name-only --diff-filter=U)
  if echo "$CONFLICTED_FILES" | grep -q "db/schema.rb"; then
    git checkout --theirs db/schema.rb
    git add db/schema.rb
    echo -e "${GREEN}Resolved db/schema.rb conflict.${NC}"
  fi

  # Check for other conflicts
  REMAINING_CONFLICTS=$(git diff --name-only --diff-filter=U 2>/dev/null || true)
  if [ -n "$REMAINING_CONFLICTS" ]; then
    echo -e "${RED}Unresolved conflicts in:${NC}"
    echo "$REMAINING_CONFLICTS"
    echo -e "${RED}Please resolve manually, then run:${NC}"
    echo "  git add . && git commit --no-verify -m 'Merge upstream/develop into develop'"
    exit 1
  fi

  git commit --no-verify -m "Merge upstream/develop into develop"
}

echo -e "${GREEN}develop synced with upstream.${NC}"

# Step 4: Merge develop into client branch
echo -e "${YELLOW}Step 4: Merging develop into ${CLIENT_BRANCH}...${NC}"

# Check if client branch exists locally
if git branch --list "$CLIENT_BRANCH" | grep -q "$CLIENT_BRANCH"; then
  git checkout "$CLIENT_BRANCH"
else
  # Create from origin if exists
  if git branch -r | grep -q "origin/$CLIENT_BRANCH"; then
    git checkout -b "$CLIENT_BRANCH" "origin/$CLIENT_BRANCH"
  else
    echo -e "${RED}Branch ${CLIENT_BRANCH} not found locally or on origin.${NC}"
    echo -e "${YELLOW}Creating new branch from develop...${NC}"
    git checkout -b "$CLIENT_BRANCH"
  fi
fi

git merge develop --no-edit 2>&1 || {
  echo -e "${YELLOW}Merge conflicts detected in ${CLIENT_BRANCH}.${NC}"
  CONFLICTED_FILES=$(git diff --name-only --diff-filter=U)
  echo -e "${RED}Conflicts in:${NC}"
  echo "$CONFLICTED_FILES"
  echo ""
  echo -e "${YELLOW}For branding files (installation_config.yml, logos), you may want to keep client versions.${NC}"
  echo -e "${RED}Please resolve conflicts manually, then run:${NC}"
  echo "  git add . && git commit --no-verify -m 'Merge develop into ${CLIENT_BRANCH}'"
  exit 1
}

echo -e "${GREEN}${CLIENT_BRANCH} updated with develop.${NC}"

# Step 5: Summary
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Sync complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Upstream commits merged into develop:"
git log --oneline develop..upstream/develop 2>/dev/null | head -10 || echo "(none)"
echo ""
echo "Next steps:"
echo "  1. Verify branding files are intact on ${CLIENT_BRANCH}"
echo "  2. Run tests: bundle exec rspec && pnpm test"
echo "  3. Push branches:"
echo "     git push origin develop"
echo "     git push origin ${CLIENT_BRANCH}"
echo "  4. Rebuild Docker image for deployment"
echo ""
echo "Note: Push to develop may be blocked by branch protection."
echo "      Consider creating a PR from a sync branch instead."
