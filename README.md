# Code Review Agent

Automated code review system using Claude AI with A/B risk classification.

## Overview

This repository contains the central configuration for AI-powered code reviews across all Taddle repositories. It provides:

- **A-Class Risk Detection**: Blocking issues requiring human approval
- **B-Class Risk Detection**: Non-blocking suggestions

## Risk Classification

### A-Class Risks (Blocking)

| Code | Risk Type | Description |
|------|-----------|-------------|
| A1 | Implicit Assumptions | Code that assumes conditions without validation |
| A2 | Multi-location State | Shared state modified in multiple places |
| A3 | Incomplete Branches | Missing edge case handling |
| A4 | Unsafe Async | Async operations without timeout/cancellation |
| A5 | Poor Error Handling | Errors swallowed or not propagated |
| A6 | Ambiguous Functions | Functions with unclear responsibilities |

### B-Class Risks (Suggestions)

| Code | Risk Type | Description |
|------|-----------|-------------|
| B1 | Type Contracts | Magic numbers, raw strings instead of enums |
| B2 | Serialization | Manual serialization, implicit defaults |
| B3 | Test Coverage | Missing tests for critical paths |
| B4 | Maintainability | DRY violations, redundant code |
| B5 | Observability | Missing logging, metrics, crash reporting |
| B6 | UI Consistency | Missing standard UI patterns |

## Repository Structure

```
code-review-agent/
├── README.md
├── .github/
│   └── workflows/
│       └── sync-to-repos.yml     # Syncs workflows to target repos
├── rules/
│   ├── a-class-risks.md          # A-class risk definitions
│   ├── b-class-risks.md          # B-class risk definitions
│   ├── swift-patterns.md         # iOS/Swift patterns
│   ├── python-patterns.md        # Python/FastAPI patterns
│   ├── go-patterns.md            # Go patterns
│   └── cdk-patterns.md           # TypeScript/CDK patterns
├── workflows/
│   ├── code-review-backend.yml   # For Taddle-Backend
│   ├── code-review-frontend.yml  # For Taddle-frontend
│   └── code-review-infra.yml     # For Taddle-Infra
└── scripts/
    └── install.sh                # One-click installation
```

## Installation

### Quick Install

```bash
./scripts/install.sh
```

### Manual Install

1. Copy the appropriate workflow file to your repository:
   ```bash
   # For Backend
   cp workflows/code-review-backend.yml YOUR_REPO/.github/workflows/code-review.yml

   # For Frontend
   cp workflows/code-review-frontend.yml YOUR_REPO/.github/workflows/code-review.yml

   # For Infra
   cp workflows/code-review-infra.yml YOUR_REPO/.github/workflows/code-review.yml
   ```

2. Add the `ANTHROPIC_API_KEY` secret to your repository:
   ```bash
   gh secret set ANTHROPIC_API_KEY -R YoumigoTech/YOUR_REPO
   ```

3. (Optional) Configure branch protection rules to require the status check.

## Configuration

### Required Secrets

| Secret | Description |
|--------|-------------|
| `ANTHROPIC_API_KEY` | API key for Claude AI |
| `REPO_ACCESS_TOKEN` | (For sync workflow) PAT with repo access |

### Branch Protection (Recommended)

Configure these settings in your repository:

```
Settings > Branches > main

✓ Require pull request reviews before merging
✓ Require status checks: "AI Code Review / risk-scan"
✓ Require conversation resolution before merging
```

### CODEOWNERS (Optional)

Add a CODEOWNERS file to require senior review for critical files:

```
# Example for Backend
app/services/auth*.py    @senior-backend
app/core/security.py     @senior-backend

# Example for Frontend
Taddle/Core/Services/*.swift @senior-ios

# Example for Infra
lib/*-stack.ts           @senior-devops
```

## How It Works

### Workflow

```
PR Created/Updated
       │
       ▼
┌──────────────────────┐
│  Fetch Review Rules  │
│  from this repo      │
└──────────────────────┘
       │
       ▼
┌──────────────────────┐
│   Claude AI Scan     │
│   Classify Risks     │
└──────────────────────┘
       │
       ├─── A-Class Found ────▶ Block PR, Require Review
       │
       └─── B-Class Only ────▶ Post Suggestions, Allow Merge
```

### A-Class Risk Handling

When an A-class risk is detected:

1. PR is blocked from merging
2. Risk report posted as PR comment
3. Developer must either:
   - Fix the issue
   - Add `// RISK-ACCEPTED: A1 - [reason]` comment
   - Request exemption from senior engineer

### B-Class Risk Handling

When a B-class risk is detected:

1. Suggestion comment posted on PR
2. Developer can accept or ignore
3. PR is not blocked

## Customization

### Adding New Rules

1. Edit the appropriate file in `rules/`
2. Follow the existing format for patterns
3. Commit and push to main
4. Rules are automatically fetched on next PR scan

### Adding Language Support

1. Create a new pattern file: `rules/[language]-patterns.md`
2. Create a new workflow: `workflows/code-review-[project].yml`
3. Update the workflow to fetch the new pattern file

## Cost Estimation

| Model | Usage | Est. Cost/Month |
|-------|-------|-----------------|
| Claude Sonnet | PR scanning | ~$50-80 |
| GitHub Actions | Workflow runs | Free tier |

## Troubleshooting

### Workflow Not Triggering

- Check that the workflow file is in `.github/workflows/`
- Verify the `paths` filter matches your file types
- Ensure `ANTHROPIC_API_KEY` secret is set

### False Positives

- Add `// RISK-ACCEPTED: [code] - [reason]` to intentionally skip
- Submit PR to update rules in this repo

### Missing Suggestions

- Check the Claude AI response in the workflow logs
- Ensure the diff contains reviewable code

## Contributing

1. Create a feature branch
2. Update rules or workflows
3. Test locally if possible
4. Submit PR for review

## License

Internal use only - YoumigoTech
