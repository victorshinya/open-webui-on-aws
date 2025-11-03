# Cognito Setup Guide

This guide provides detailed instructions for configuring AWS Cognito for Open WebUI authentication.

## Overview

AWS Cognito provides user authentication and authorization for Open WebUI using OAuth 2.0 and OpenID Connect (OIDC) protocols.

## Prerequisites

- AWS Account with Cognito permissions
- Domain name for Open WebUI (or ALB DNS)
- Basic understanding of OAuth 2.0

## Option 1: Using CloudFormation (Recommended)

The CloudFormation templates automatically create and configure Cognito. You only need to:

1. **Specify parameters** in your parameters file
2. **Deploy the stack**
3. **Update the client secret** (post-deployment)
4. **Create users**

See [AWS Deployment Guide](aws-deployment.md) for complete instructions.

## Option 2: Manual Cognito Setup

If you prefer to create Cognito manually or use an existing User Pool:

### Step 1: Create User Pool

1. **Navigate to Cognito Console:**
   ```
   https://console.aws.amazon.com/cognito/
   ```

2. **Click "Create user pool"**

3. **Configure sign-in experience:**
   - Sign-in options: **Email**
   - User name requirements: **Allow users to sign in with email**
   - Click "Next"

4. **Configure security requirements:**
   - Password policy:
     - Minimum length: **8 characters** (12+ for production)
     - Require uppercase: **Yes**
     - Require lowercase: **Yes**
     - Require numbers: **Yes**
     - Require special characters: **Optional**
   - Multi-factor authentication: **Optional** (or **Required** for production)
   - MFA methods: **Authenticator apps** (TOTP)
   - Click "Next"

5. **Configure sign-up experience:**
   - Self-registration: **Enable** (or disable if managing users manually)
   - Attribute verification: **Email**
   - Required attributes:
     - **email** (required)
     - **name** (optional)
   - Custom attributes:
     - Add `role` (String, mutable)
     - Add `organization` (String, mutable)
   - Click "Next"

6. **Configure message delivery:**
   - Email provider: **Send email with Cognito** (or use SES for production)
   - FROM email address: **no-reply@verificationemail.com** (or custom)
   - Click "Next"

7. **Integrate your app:**
   - User pool name: `open-webui-prod`
   - Hosted authentication pages: **Use Cognito Hosted UI**
   - Domain type: **Use a Cognito domain**
   - Cognito domain: `my-openwebui-prod` (must be globally unique)
   - Click "Next"

8. **Review and create:**
   - Review all settings
   - Click "Create user pool"

### Step 2: Create App Client

1. **In your User Pool, go to "App integration" tab**

2. **Click "Create app client"**

3. **Configure app client:**
   - App client name: `open-webui-client`
   - Client secret: **Generate a client secret** ✓
   - Authentication flows:
     - **ALLOW_USER_SRP_AUTH** ✓
     - **ALLOW_REFRESH_TOKEN_AUTH** ✓
   - Click "Next"

4. **Configure OAuth 2.0:**
   - Allowed callback URLs:
     ```
     https://your-domain.com/oauth/callback
     ```
   - Allowed sign-out URLs:
     ```
     https://your-domain.com
     ```
   - OAuth 2.0 grant types:
     - **Authorization code grant** ✓
   - OpenID Connect scopes:
     - **openid** ✓
     - **email** ✓
     - **profile** ✓
   - Click "Create app client"

5. **Save credentials:**
   - Copy **App client ID**
   - Click "Show client secret" and copy **Client secret**
   - Save these securely - you'll need them for configuration

### Step 3: Create User Groups

1. **Go to "Groups" tab in your User Pool**

2. **Create "Admins" group:**
   - Group name: `Admins`
   - Description: `Administrator users with full access`
   - Precedence: `1`
   - Click "Create group"

3. **Create "Users" group:**
   - Group name: `Users`
   - Description: `Standard users with basic access`
   - Precedence: `10`
   - Click "Create group"

### Step 4: Create Test User

1. **Go to "Users" tab**

2. **Click "Create user":**
   - Email: `admin@example.com`
   - Temporary password: `TempPass123!`
   - Email verified: **Mark as verified** ✓
   - Click "Create user"

3. **Add user to Admins group:**
   - Select the user
   - Click "Add user to group"
   - Select "Admins"
   - Click "Add"

## Configuration for Open WebUI

### Local Development

Update `.env.local`:

```bash
# Cognito Configuration
COGNITO_USER_POOL_ID=us-east-1_xxxxxxxxx
OAUTH_CLIENT_ID=your-client-id
OAUTH_CLIENT_SECRET=your-client-secret
AWS_REGION=us-east-1
COGNITO_DOMAIN=my-openwebui-prod.auth.us-east-1.amazoncognito.com

# OAuth URLs (auto-constructed)
OPENID_PROVIDER_URL=https://cognito-idp.us-east-1.amazonaws.com/us-east-1_xxxxxxxxx
OAUTH_REDIRECT_URI=http://localhost:3000/oauth/callback

# OAuth Settings
OAUTH_PROVIDER_NAME=AWS Cognito
OAUTH_SCOPES=openid profile email
ENABLE_OAUTH_SIGNUP=true
OAUTH_MERGE_ACCOUNTS_BY_EMAIL=true
```

### AWS Deployment

The CloudFormation template automatically configures these environment variables in the ECS task definition.

## Advanced Configuration

### Custom Email Templates

1. **Go to "Messaging" tab in User Pool**

2. **Customize email templates:**
   - Verification email
   - Invitation email
   - Password reset email

3. **Use HTML templates:**
   ```html
   <h1>Welcome to Open WebUI</h1>
   <p>Your verification code is: {####}</p>
   ```

### Custom Domain

Instead of Cognito domain, use your own:

1. **Go to "App integration" → "Domain"**

2. **Click "Actions" → "Create custom domain"**

3. **Enter your domain:**
   - Custom domain: `auth.example.com`
   - ACM certificate: Select certificate

4. **Add CNAME record to DNS:**
   ```
   auth.example.com → xxxxx.cloudfront.net
   ```

### Advanced Security

**Enable Advanced Security Features:**

1. **Go to "Security" tab**

2. **Enable "Advanced security":**
   - Adaptive authentication
   - Compromised credentials check
   - Custom authentication challenges

**Configure Risk-Based Authentication:**

- Low risk: Allow
- Medium risk: Require MFA
- High risk: Block

### Lambda Triggers

Add custom logic with Lambda triggers:

1. **Go to "User pool properties" → "Lambda triggers"**

2. **Available triggers:**
   - Pre sign-up: Validate user data
   - Post confirmation: Send welcome email
   - Pre authentication: Custom validation
   - Post authentication: Log user activity
   - Pre token generation: Add custom claims

**Example: Add custom claims**

```javascript
exports.handler = async (event) => {
    event.response = {
        claimsOverrideDetails: {
            claimsToAddOrOverride: {
                'custom:role': 'admin',
                'custom:organization': 'acme-corp'
            }
        }
    };
    return event;
};
```

## User Management

### Creating Users via CLI

```bash
# Create user
aws cognito-idp admin-create-user \
  --user-pool-id us-east-1_xxxxxxxxx \
  --username user@example.com \
  --user-attributes Name=email,Value=user@example.com Name=email_verified,Value=true \
  --temporary-password "TempPass123!" \
  --message-action SUPPRESS \
  --region us-east-1

# Add to group
aws cognito-idp admin-add-user-to-group \
  --user-pool-id us-east-1_xxxxxxxxx \
  --username user@example.com \
  --group-name Users \
  --region us-east-1

# Set permanent password
aws cognito-idp admin-set-user-password \
  --user-pool-id us-east-1_xxxxxxxxx \
  --username user@example.com \
  --password "PermanentPass123!" \
  --permanent \
  --region us-east-1
```

### Bulk User Import

1. **Create CSV file:**
   ```csv
   name,email,email_verified,cognito:username
   John Doe,john@example.com,true,john@example.com
   Jane Smith,jane@example.com,true,jane@example.com
   ```

2. **Create import job:**
   ```bash
   aws cognito-idp create-user-import-job \
     --user-pool-id us-east-1_xxxxxxxxx \
     --job-name "initial-users" \
     --cloud-watch-logs-role-arn arn:aws:iam::ACCOUNT:role/CognitoImportRole \
     --region us-east-1
   ```

3. **Upload CSV to S3 and start job**

### Disabling/Enabling Users

```bash
# Disable user
aws cognito-idp admin-disable-user \
  --user-pool-id us-east-1_xxxxxxxxx \
  --username user@example.com \
  --region us-east-1

# Enable user
aws cognito-idp admin-enable-user \
  --user-pool-id us-east-1_xxxxxxxxx \
  --username user@example.com \
  --region us-east-1
```

### Resetting Passwords

```bash
# Send password reset email
aws cognito-idp admin-reset-user-password \
  --user-pool-id us-east-1_xxxxxxxxx \
  --username user@example.com \
  --region us-east-1
```

## Monitoring and Logging

### CloudWatch Metrics

Monitor Cognito usage:

- Sign-in attempts
- Sign-in successes
- Sign-in failures
- Token refresh requests

### CloudTrail Logging

Enable CloudTrail to log:

- User pool changes
- User creation/deletion
- Authentication attempts
- Configuration changes

## Security Best Practices

1. **Enable MFA** for all admin users
2. **Use strong password policies** (12+ characters)
3. **Enable advanced security features**
4. **Rotate client secrets** regularly
5. **Monitor failed login attempts**
6. **Use custom domains** for branding
7. **Implement account lockout** policies
8. **Enable CloudTrail logging**
9. **Review user activity** regularly
10. **Use groups** for access control

## Troubleshooting

### Common Issues

**"Domain already exists"**
- Choose a different domain prefix
- Domain must be globally unique

**"Invalid redirect URI"**
- Ensure callback URL matches exactly
- Check for trailing slashes
- Verify HTTPS vs HTTP

**"Client secret invalid"**
- Regenerate client secret
- Update in Secrets Manager
- Restart ECS tasks

**"User not confirmed"**
- Verify email address
- Check email verification settings
- Manually confirm user in console

### Testing Authentication

```bash
# Test OAuth flow
curl -X POST https://YOUR_DOMAIN.auth.REGION.amazoncognito.com/oauth2/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=authorization_code&client_id=CLIENT_ID&code=AUTH_CODE&redirect_uri=CALLBACK_URL"
```

## Additional Resources

- [AWS Cognito Documentation](https://docs.aws.amazon.com/cognito/)
- [OAuth 2.0 Specification](https://oauth.net/2/)
- [OpenID Connect Specification](https://openid.net/connect/)
- [Cognito Pricing](https://aws.amazon.com/cognito/pricing/)
