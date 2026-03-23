# Security Review

Performs a security review of code changes, checking for vulnerabilities and compliance with organizational security requirements.

## Steps

1. **Identify changed files**
   Determine the scope of changes to review:
   ```bash
   git diff --name-only main...HEAD
   ```

2. **Check for hardcoded secrets**
   Search for potential secrets, API keys, tokens, and credentials in changed files:
   - AWS access keys (patterns starting with `AKIA`)
   - Private key blocks in PEM format
   - Connection strings with embedded passwords
   - Hardcoded tokens, passwords, or passphrases
   - `.env` files or credentials files committed to the repo

3. **Secrets management compliance**
   - All secrets must use SSM Parameter Store (SecureString) or Secrets Manager.
   - SSM parameter values must be cached in memory with a 5-minute TTL. Expose `reset_cache()` for test isolation.
   - Never pass secrets via environment variables in CI logs or error messages.

4. **Check for injection vulnerabilities**
   - **SQL injection**: Raw string concatenation in SQL queries. Require parameterized queries.
   - **Command injection**: Unsanitized input passed to shell-executing functions (`subprocess` with `shell=True`). Require argument lists.
   - **XSS**: User input rendered in HTML without escaping.
   - **Template injection**: User input in format strings, Jinja templates, or f-strings used in prompts.
   - **Path traversal**: User-supplied file paths without validation (directory traversal with `../`).

5. **Input validation**
   - Validate and sanitize all external input at API boundaries (Lambda handler level).
   - Never trust user-supplied data passed to DynamoDB expressions, file paths, or shell commands.

6. **Review OWASP Top 10 concerns**
   - **Broken access control**: Missing authorization checks, overly permissive IAM policies, CORS misconfigurations.
   - **Cryptographic failures**: Weak algorithms (MD5, SHA1 for security), missing encryption at rest or in transit.
   - **Insecure design**: Missing rate limiting, no input validation at system boundaries.
   - **Security misconfiguration**: Debug mode enabled, default credentials, unnecessary permissions.
   - **Vulnerable dependencies**: Check `requirements.txt` for known vulnerable versions.
   - **Authentication failures**: Weak token generation, session management issues.
   - **Data integrity failures**: Missing signature verification, insecure deserialization (unsafe YAML loading).
   - **Logging failures**: Sensitive data in logs (passwords, tokens, PII).
   - **SSRF**: User-controlled URLs in server-side HTTP requests without validation.

7. **Review IAM and infrastructure**
   For SAM/CloudFormation templates:
   - No wildcard (`*`) in IAM actions or resources unless justified.
   - Principle of least privilege applied.
   - Encryption enabled for data at rest (DynamoDB, S3).
   - DynamoDB point-in-time recovery enabled for production tables.
   - API Gateway endpoints must use API keys or IAM auth -- never expose unauthenticated endpoints to the public internet unless explicitly required.

8. **Check dependency security**
   If dependency files changed:
   ```bash
   pip audit  # if pip-audit is installed
   ```

## Output

Provide a summary with severity levels:
- **Critical**: Issues that must be fixed before merge (secrets, injection, broken auth).
- **High**: Issues that should be fixed soon (weak crypto, missing validation).
- **Medium**: Issues to address (verbose error messages, missing rate limiting).
- **Low**: Suggestions for improvement (logging hygiene, dependency updates).

For each finding, include the file path, line number, description, and a recommended fix.
