# Organization CLAUDE.md

<!-- This file is synced to every developer's ~/.claude/CLAUDE.md on session start. -->
<!-- Detailed standards are in org/skills/ -- this file provides the high-level rules and references. -->

## Tech Stack

- **Language**: Python 3.12+
- **Infrastructure as Code**: AWS SAM (`template.yaml`)
- **Runtime**: AWS Lambda
- **API**: Amazon API Gateway (HTTP API v2 preferred, REST API v1 when features require it)
- **Database**: Amazon DynamoDB
- **Supporting services**: S3, SQS, SNS, EventBridge, SSM Parameter Store, Secrets Manager

## Project Structure

All serverless projects must follow this layout:

```
project-root/
  template.yaml          # SAM template (single source of truth for infra)
  samconfig.toml         # SAM deployment config per environment
  src/
    handlers/            # Lambda handler modules (one per function)
    models/              # Data models (@dataclass with DynamoDB serialization)
    services/            # Business logic (decoupled from Lambda event shape)
    utils/               # Shared helpers (logging setup, AWS client factories)
  tests/
    unit/                # Fast tests with moto mocks, no real AWS calls
    integration/         # Tests against deployed stack (gated by env var)
    conftest.py          # Shared fixtures: DynamoDB table creation, event builders
  scripts/               # Deployment, seeding, and operational scripts
```

## Key Rules (Summary)

These are the non-negotiable rules. Full details live in the skill files referenced below.

- **Handlers must be thin**: parse event, call service, return response. Business logic goes in `src/services/`.
- **No `print()`**: use `logging` module with `logger.exception()` in except blocks.
- **DynamoDB reserved words**: always use `ExpressionAttributeNames` with `#placeholder` syntax.
- **DynamoDB pagination**: always loop until `LastEvaluatedKey` is absent.
- **Stack isolation**: use `AWS::StackName` for all dynamic naming and SSM parameter scoping.
- **No hardcoded secrets**: use SSM Parameter Store (SecureString) or Secrets Manager.
- **Every PR needs tests**: unit tests for new logic, `sam validate` for template changes.

## Skills

The following skills contain detailed standards and can be invoked for reviews:

| Skill | Purpose |
|-------|---------|
| `/python-standards` | Python code style, Lambda handler patterns, logging, error handling |
| `/dynamodb-standards` | DynamoDB data modeling, queries, pagination, write safety |
| `/sam-standards` | SAM template rules, IAM policies, deployment configuration |
| `/testing-standards` | pytest, moto mocking, fixtures, coverage expectations |
| `/security-review` | Secrets, injection vulnerabilities, OWASP Top 10, IAM review |
| `/code-review` | Full PR review combining all standards above |

### Invoking Skills

- Run `/code-review` for a comprehensive PR review that covers all standards.
- Run individual skills (e.g., `/python-standards`, `/sam-standards`) for focused reviews on specific areas.
- The `/code-review` skill references the specialized skills, so it serves as the primary entry point.

Skills are located in `org/skills/<skill-name>/SKILL.md`.
