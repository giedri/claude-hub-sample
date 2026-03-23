# Code Review

Performs a comprehensive code review of a pull request, checking against all organizational standards for serverless Python development on AWS.

## Steps

1. **Identify changed files**
   Determine the scope of changes to review:
   ```bash
   git diff --name-only main...HEAD
   ```

2. **Naming conventions**
   - **Python**: snake_case for functions, variables, modules. PascalCase for classes. UPPER_SNAKE_CASE for constants.
   - **Files**: snake_case for Python modules.
   - **CloudFormation resources**: PascalCase logical IDs.
   - **DynamoDB**: snake_case for attribute names. PascalCase for table logical IDs.
   - Boolean variables and functions should read as predicates: `is_valid`, `has_access`, `should_retry`.

3. **Code organization**
   - Handlers must be thin: parse event, call service, return response.
   - Business logic belongs in `src/services/`, not in handler modules.
   - Shared utilities belong in `src/utils/` or a Lambda layer, not duplicated across handlers.
   - Configuration must come from environment variables, not hardcoded values.
   - Use `@dataclass` for structured data, not raw dicts with string keys.
   - Functions should do one thing. If a function exceeds ~50 lines, consider splitting.
   - No circular imports.

4. **PR quality checks**
   - PR title should follow Conventional Commits format: `type(scope): description`.
   - PR description should explain **what** changed and **why**.
   - DynamoDB access patterns must be documented when adding new queries or GSIs.
   - Lambda functions must not exceed 512 MB memory or 30-second timeout without documented justification.
   - No `print()` statements -- use structured logging.

5. **Run related skill checks**
   Apply the following specialized reviews as relevant to the changed files:
   - **Python standards** (`/python-standards`): For any changed `.py` files.
   - **DynamoDB standards** (`/dynamodb-standards`): For code touching DynamoDB or table definitions in templates.
   - **SAM standards** (`/sam-standards`): For `template.yaml`, `samconfig.toml`, or infrastructure changes.
   - **Testing standards** (`/testing-standards`): For test files or when production code lacks corresponding tests.
   - **Security review** (`/security-review`): For all changes.

6. **Documentation**
   - Public functions and classes should have docstrings explaining purpose and parameters.
   - Complex business logic should have inline comments explaining "why", not "what".
   - API endpoints should document request/response formats.

## Output

Provide a structured review with:
- **Summary**: One-paragraph overview of the changes and overall assessment.
- **Blockers**: Issues that must be fixed before merge.
- **Suggestions**: Recommended improvements that are not blocking.
- **Nits**: Minor style or readability notes.

For each finding, include the file path, line number, the issue, and a recommended fix.
