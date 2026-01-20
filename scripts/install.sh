#!/bin/bash

# Code Review Agent Installation Script
# This script installs the code review workflow to a target repository

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Code Review Agent Installer ===${NC}"
echo ""

# Check if gh CLI is installed
if ! command -v gh &> /dev/null; then
    echo -e "${RED}Error: GitHub CLI (gh) is not installed.${NC}"
    echo "Please install it first: brew install gh"
    exit 1
fi

# Check if authenticated
if ! gh auth status &> /dev/null; then
    echo -e "${RED}Error: Not authenticated with GitHub CLI.${NC}"
    echo "Please run: gh auth login"
    exit 1
fi

# Get target repository
echo "Select target repository:"
echo "  1) Taddle-Backend (Python/FastAPI)"
echo "  2) Taddle-frontend (Swift/iOS)"
echo "  3) Taddle-Infra (TypeScript/CDK)"
echo "  4) Custom repository"
echo ""
read -p "Enter choice (1-4): " choice

case $choice in
    1)
        REPO="YoumigoTech/Taddle-Backend"
        WORKFLOW_FILE="code-review-backend.yml"
        ;;
    2)
        REPO="YoumigoTech/Taddle-frontend"
        WORKFLOW_FILE="code-review-frontend.yml"
        ;;
    3)
        REPO="YoumigoTech/Taddle-Infra"
        WORKFLOW_FILE="code-review-infra.yml"
        ;;
    4)
        read -p "Enter repository (owner/repo): " REPO
        echo "Select workflow type:"
        echo "  1) Backend (Python)"
        echo "  2) Frontend (Swift)"
        echo "  3) Infra (TypeScript/CDK)"
        read -p "Enter choice (1-3): " wf_choice
        case $wf_choice in
            1) WORKFLOW_FILE="code-review-backend.yml" ;;
            2) WORKFLOW_FILE="code-review-frontend.yml" ;;
            3) WORKFLOW_FILE="code-review-infra.yml" ;;
            *) echo -e "${RED}Invalid choice${NC}"; exit 1 ;;
        esac
        ;;
    *)
        echo -e "${RED}Invalid choice${NC}"
        exit 1
        ;;
esac

echo ""
echo -e "${YELLOW}Installing to: ${REPO}${NC}"
echo ""

# Clone target repo
TEMP_DIR=$(mktemp -d)
echo "Cloning repository..."
gh repo clone "$REPO" "$TEMP_DIR" -- --depth 1

# Create workflows directory if not exists
mkdir -p "$TEMP_DIR/.github/workflows"

# Get the script's directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKFLOWS_DIR="$(dirname "$SCRIPT_DIR")/workflows"

# Copy workflow file
echo "Copying workflow file..."
cp "$WORKFLOWS_DIR/$WORKFLOW_FILE" "$TEMP_DIR/.github/workflows/code-review.yml"

# Check if ANTHROPIC_API_KEY secret exists
echo ""
echo -e "${YELLOW}Checking repository secrets...${NC}"
if ! gh secret list -R "$REPO" | grep -q "ANTHROPIC_API_KEY"; then
    echo -e "${RED}Warning: ANTHROPIC_API_KEY secret not found in repository.${NC}"
    echo ""
    echo "You need to add the ANTHROPIC_API_KEY secret to the repository."
    echo "Run: gh secret set ANTHROPIC_API_KEY -R $REPO"
    echo ""
    read -p "Do you want to set it now? (y/n): " set_secret
    if [[ $set_secret == "y" ]]; then
        read -sp "Enter your Anthropic API key: " api_key
        echo ""
        echo "$api_key" | gh secret set ANTHROPIC_API_KEY -R "$REPO"
        echo -e "${GREEN}Secret set successfully!${NC}"
    fi
fi

# Commit and push
cd "$TEMP_DIR"
git checkout -b feature/add-code-review-workflow

git add .github/workflows/code-review.yml
git commit -m "feat: add AI code review workflow

- Add automated code review using Claude
- Classify risks as A-class (blocking) or B-class (suggestions)
- Automatically scan PRs for code quality issues"

echo ""
echo "Pushing changes..."
git push -u origin feature/add-code-review-workflow

# Create PR
echo ""
echo "Creating pull request..."
PR_URL=$(gh pr create \
    --title "Add AI Code Review Workflow" \
    --body "## Summary

This PR adds an automated code review workflow powered by Claude AI.

### Features
- **A-class risks**: Blocking issues that require human review
- **B-class risks**: Suggestions that developers can accept/reject

### Risk Categories
- A1: Implicit assumptions not validated
- A2: State modified in multiple places
- A3: Incomplete conditional branches
- A4: Complex async without guarantees
- A5: Error paths not first-class
- A6: Ambiguous function responsibilities

### Setup Required
- [x] Workflow file added
- [ ] ANTHROPIC_API_KEY secret configured
- [ ] Branch protection rules configured (optional)

### Next Steps
1. Review and merge this PR
2. Configure branch protection to require 'AI Code Review / risk-scan' status check
3. Test by creating a PR with intentional issues
" \
    --repo "$REPO")

echo ""
echo -e "${GREEN}=== Installation Complete ===${NC}"
echo ""
echo "Pull request created: $PR_URL"
echo ""
echo "Next steps:"
echo "  1. Review and merge the PR"
echo "  2. Ensure ANTHROPIC_API_KEY secret is configured"
echo "  3. (Optional) Configure branch protection rules"
echo ""

# Cleanup
rm -rf "$TEMP_DIR"
