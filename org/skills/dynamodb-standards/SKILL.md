# DynamoDB Standards Review

Checks DynamoDB data modeling, queries, and operations against organizational standards.

## Steps

1. **Identify changed files**
   Determine the scope of changes involving DynamoDB:
   ```bash
   git diff --name-only main...HEAD
   ```
   Look for files that import `boto3` and reference `dynamodb`, as well as CloudFormation/SAM template changes to DynamoDB tables.

2. **Data modeling standards**
   - Use single-table design when entities share access patterns. Use separate tables only when access patterns are completely independent.
   - Name partition keys `pk` and sort keys `sk` for single-table designs. Use descriptive names for single-entity tables.
   - Store timestamps as ISO 8601 strings. Store TTL values as Unix epoch integers.
   - TTL attribute must be a Unix epoch timestamp (number), not an ISO string. Enable TTL in the CloudFormation template with `TimeToLiveSpecification`.

3. **Reserved words**
   - Always use `ExpressionAttributeNames` with `#placeholder` syntax for any attribute that could be a DynamoDB reserved word.
   - Common reserved words: `status`, `name`, `type`, `data`, `action`, `key`, `value`, `count`, `size`, `url`.

4. **Query and scan operations**
   - Always handle pagination: loop until `LastEvaluatedKey` is absent for scan and query operations.
   - A single scan/query may return partial data (1 MB limit per page).

   Correct pagination pattern:
   ```python
   def query_all(table, **kwargs):
       items = []
       response = table.query(**kwargs)
       items.extend(response["Items"])
       while "LastEvaluatedKey" in response:
           response = table.query(ExclusiveStartKey=response["LastEvaluatedKey"], **kwargs)
           items.extend(response["Items"])
       return items
   ```

5. **Write operations**
   - Use conditional writes for idempotency: `ConditionExpression="attribute_not_exists(pk)"` to prevent duplicate inserts.
   - Use `ADD` in UpdateExpression for atomic counters: `UpdateExpression="ADD counter_field :inc"` with `:inc = 1`.

6. **Concurrency and connection management**
   - Configure `botocore.config.Config(max_pool_connections=25)` when using `ThreadPoolExecutor` with many concurrent DynamoDB calls.

7. **CloudFormation/SAM template checks**
   - CloudFormation can only add or remove one GSI per stack update. If multiple GSI changes are needed, delete the stack and redeploy.
   - Enable encryption at rest (default) and point-in-time recovery for production tables.

## Output

Provide a summary organized by category:
- **Data modeling**: Schema design issues or naming violations.
- **Reserved words**: Missing `ExpressionAttributeNames` placeholders.
- **Pagination**: Queries or scans that don't handle `LastEvaluatedKey`.
- **Write safety**: Missing conditional writes or incorrect update expressions.
- **Infrastructure**: SAM/CloudFormation template issues for DynamoDB resources.

For each finding, include the file path, line number, the issue, and the recommended fix.
