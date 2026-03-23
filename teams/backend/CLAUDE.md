# Backend Team - Team CLAUDE.md

## Team Overview

- **Team name**: Backend
- **Domain**: APIs, business logic, data processing, and infrastructure
- **Slack channel**: #team-backend
- **On-call rotation**: https://pagerduty.internal.acme.com/backend
- **Team lead**: TBD

## Tech Stack

- **Languages**: Python 3.12+
- **Frameworks**: AWS Lambda handlers (thin), service layer pattern
- **Infrastructure**: AWS SAM, API Gateway (HTTP API v2), Lambda, DynamoDB, SQS, SNS, EventBridge, Step Functions
- **Databases**: DynamoDB (primary), S3 (blob storage), ElastiCache Redis (caching)
- **CI/CD**: GitHub Actions with shared workflows
- **Testing**: pytest, moto, Hypothesis, Locust (load testing)

## Team Conventions

### Code Style

- Use Black (line length 100) and isort for formatting.
- Use Ruff for linting with default rules.
- Type hints on all function signatures. Use `mypy --strict` in CI.
- Prefer `@dataclass(frozen=True)` for immutable value objects.

### Service Architecture

- Each Lambda function maps to one bounded context or domain action.
- Business logic lives in `src/services/`, never in handlers.
- Cross-service communication via SQS (async) or API Gateway (sync). No direct Lambda-to-Lambda invocation.
- Use Step Functions for multi-step orchestration workflows instead of chaining Lambdas.
- Event-driven patterns preferred: publish domain events to EventBridge, let downstream services subscribe.

### API Design

- RESTful resource naming: plural nouns (`/users`, `/orders`), not verbs.
- Use HTTP methods correctly: GET (read), POST (create), PUT (full update), PATCH (partial update), DELETE.
- Pagination: cursor-based using `next_token` query parameter. Never use offset-based pagination with DynamoDB.
- Error responses follow a consistent schema: `{"error": {"code": "NOT_FOUND", "message": "..."}}`.
- Version via URL path (`/v1/resource`) per org standard.
- Rate limiting enforced at API Gateway level using usage plans and API keys.

### DynamoDB Patterns

- Single-table design for related entities within a service boundary.
- Access patterns documented in `docs/access-patterns.md` for each service.
- GSI naming convention: `gsi1` through `gsiN` for single-table, descriptive names for single-entity tables.
- Use DynamoDB Streams + Lambda for change data capture and cross-service event propagation.
- Batch operations (`batch_write_item`) for bulk inserts with exponential backoff on unprocessed items.

### Async Processing

- SQS queues for work that can be deferred (email sending, report generation, data enrichment).
- Dead-letter queues on all SQS queues with `maxReceiveCount=3`.
- Lambda concurrency limits set per function to avoid throttling downstream services.
- Idempotency keys stored in DynamoDB for at-least-once delivery deduplication.

### Branching Strategy

- Short-lived feature branches off `main`.
- Branch naming: `{type}/{ticket-id}-{short-description}` (e.g., `feat/BE-456-order-refunds`).
- Squash merge to main.

### Testing Standards

- Unit tests with pytest and moto for all service logic.
- Integration tests against deployed stack gated by `INTEGRATION_TEST=1` env var.
- Load tests with Locust for any new API endpoint before production launch.
- Property-based tests with Hypothesis for data model serialization and validation.
- Minimum 85% code coverage for new code.
- Contract tests for inter-service API boundaries.

### Deployment

- Deploy to staging automatically on merge to main via `sam deploy`.
- Production deploys require manual approval in GitHub Actions.
- Use Lambda aliases and gradual deployment (CodeDeploy `Linear10PercentEvery1Minute`) for production.
- Database migrations (GSI additions) deployed separately from code changes.

## Overrides

### Code Coverage Threshold

- **Org standard**: Tests required for new logic (no specific threshold).
- **Team override**: Minimum 85% code coverage enforced in CI for new code.
- **Reason**: Backend services are critical infrastructure. Higher coverage requirement catches edge cases in business logic and error handling paths.

### PR Size Limit

- **Org standard**: Keep PRs under 400 lines of diff.
- **Team override**: Allow PRs up to 600 lines for DynamoDB migration changes and SAM template updates.
- **Reason**: DynamoDB table definitions and GSI configurations are verbose but straightforward to review.
