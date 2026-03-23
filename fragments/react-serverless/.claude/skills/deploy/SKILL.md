# Deploy

Deploys the React frontend to S3/CloudFront and the BFF Lambda functions via SAM.

## Steps

1. **Run frontend checks**
   ```bash
   npm run lint
   npm run typecheck
   npm test -- --run
   ```
   Do not deploy if any check fails.

2. **Build the frontend**
   ```bash
   npm run build
   ```

3. **Build and deploy BFF Lambdas**
   ```bash
   sam validate --lint
   sam build
   sam deploy
   ```

4. **Deploy static assets to S3**
   Extract the S3 bucket name and CloudFront distribution ID from stack outputs:
   ```bash
   STACK_NAME=$(grep stack_name samconfig.toml | head -1 | awk -F'"' '{print $2}')
   BUCKET=$(aws cloudformation describe-stacks --stack-name "$STACK_NAME" --query 'Stacks[0].Outputs[?OutputKey==`WebBucketName`].OutputValue' --output text)
   DIST_ID=$(aws cloudformation describe-stacks --stack-name "$STACK_NAME" --query 'Stacks[0].Outputs[?OutputKey==`CloudFrontDistributionId`].OutputValue' --output text)
   ```

5. **Sync build output and invalidate cache**
   ```bash
   aws s3 sync dist/ "s3://$BUCKET" --delete
   aws cloudfront create-invalidation --distribution-id "$DIST_ID" --paths "/*"
   ```

6. **Verify**
   Report the CloudFront URL from stack outputs.
