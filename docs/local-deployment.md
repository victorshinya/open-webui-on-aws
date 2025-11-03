# Local Deployment Guide

This guide walks you through setting up Open WebUI locally with Docker Compose and AWS Cognito authentication.

## Prerequisites

Before you begin, ensure you have the following installed:

- **Docker Engine** 20.10 or later ([Install Docker](https://docs.docker.com/get-docker/))
- **Docker Compose** 2.0 or later (included with Docker Desktop)
- **AWS Account** with permissions to create Cognito resources
- **Git** (to clone the repository)

## Step 1: Clone the Repository

```bash
git clone <repository-url>
cd open-webui-aws-deployment
```

## Step 2: Set Up AWS Cognito

You need a Cognito User Pool for authentication. You can either:

### Option A: Use Existing Cognito User Pool

If you already have a Cognito User Pool, skip to Step 3.

### Option B: Create New Cognito User Pool

1. **Navigate to AWS Cognito Console:**
   - Go to [AWS Cognito Console](https://console.aws.amazon.com/cognito/)
   - Select your region (e.g., us-east-1)

2. **Create User Pool:**
   - Click "Create user pool"
   - Choose "Email" as sign-in option
   - Configure password policy (minimum 8 characters recommended)
   - Enable email verification
   - Click "Create pool"

3. **Create App Client:**
   - In your User Pool, go to "App integration" → "App clients"
   - Click "Create app client"
   - Name: `open-webui-local`
   - Generate client secret: **Yes** (check this box)
   - OAuth 2.0 grant types: Select "Authorization code grant"
   - OAuth scopes: Select `openid`, `email`, `profile`
   - Callback URLs: `http://localhost:3000/oauth/callback`
   - Click "Create app client"
   - **Save the Client ID and Client Secret** (you'll need these)

4. **Configure Cognito Domain:**
   - Go to "App integration" → "Domain"
   - Choose "Cognito domain"
   - Enter a unique domain prefix (e.g., `my-open-webui-local`)
   - Click "Create Cognito domain"

5. **Create Test User:**
   - Go to "Users" tab
   - Click "Create user"
   - Enter email and temporary password
   - Click "Create user"

## Step 3: Configure Environment Variables

1. **Copy the environment template:**
   ```bash
   cp .env.example .env.local
   ```

2. **Edit `.env.local` with your Cognito details:**
   ```bash
   # Required Cognito Configuration
   COGNITO_USER_POOL_ID=us-east-1_xxxxxxxxx
   OAUTH_CLIENT_ID=your-client-id-here
   OAUTH_CLIENT_SECRET=your-client-secret-here
   AWS_REGION=us-east-1
   COGNITO_DOMAIN=your-domain.auth.us-east-1.amazoncognito.com
   
   # OAuth Configuration (auto-constructed)
   OPENID_PROVIDER_URL=https://cognito-idp.us-east-1.amazonaws.com/us-east-1_xxxxxxxxx
   OAUTH_REDIRECT_URI=http://localhost:3000/oauth/callback
   
   # Generate a secret key for session encryption
   WEBUI_SECRET_KEY=<generate-with-command-below>
   
   # Optional: Port configuration
   PORT=3000
   ```

3. **Generate WEBUI_SECRET_KEY:**
   ```bash
   openssl rand -hex 32
   ```
   Copy the output and paste it as the value for `WEBUI_SECRET_KEY` in `.env.local`

## Step 4: Validate Setup

Run the setup validation script:

```bash
./scripts/local-setup.sh
```

This script will check:
- Docker and Docker Compose installation
- Environment file existence
- Required environment variables
- Port availability

If any issues are found, the script will provide guidance on how to fix them.

## Step 5: Start Open WebUI

Start the application using Docker Compose:

```bash
./scripts/start.sh
```

Or manually:
```bash
docker-compose --env-file .env.local up -d
```

The first startup may take a few minutes as Docker pulls the Open WebUI image.

## Step 6: Access Open WebUI

1. **Open your browser** and navigate to:
   ```
   http://localhost:3000
   ```

2. **You'll be redirected to Cognito login page**
   - Enter the email and password of your test user
   - If it's the first login, you'll be prompted to change the temporary password

3. **After successful authentication**, you'll be redirected back to Open WebUI

## Managing Your Local Deployment

### View Logs

```bash
./scripts/logs.sh
```

To view last 100 lines:
```bash
./scripts/logs.sh 100
```

### Stop Open WebUI

```bash
./scripts/stop.sh
```

### Restart Open WebUI

```bash
./scripts/restart.sh
```

### Reset Data (Delete Everything)

⚠️ **Warning:** This will delete all data including chat history, models, and configurations.

```bash
./scripts/reset.sh
```

## Data Persistence

All Open WebUI data is stored in a Docker volume named `open-webui-data`. This includes:

- Chat history
- User preferences
- Downloaded models
- Uploaded files
- Application database

The data persists across container restarts but will be deleted if you run `./scripts/reset.sh`.

## Troubleshooting

### Port Already in Use

If port 3000 is already in use:

1. Change the port in `.env.local`:
   ```bash
   PORT=8080
   ```

2. Update the OAuth redirect URI in Cognito:
   - Go to Cognito Console → App clients → Edit
   - Change callback URL to `http://localhost:8080/oauth/callback`

3. Update `.env.local`:
   ```bash
   OAUTH_REDIRECT_URI=http://localhost:8080/oauth/callback
   ```

4. Restart the application

### Authentication Fails

1. **Verify Cognito configuration:**
   - Check that Client ID and Secret are correct
   - Ensure callback URL matches exactly: `http://localhost:3000/oauth/callback`
   - Verify OAuth scopes include `openid`, `email`, `profile`

2. **Check container logs:**
   ```bash
   ./scripts/logs.sh
   ```
   Look for authentication-related errors

3. **Verify user exists:**
   - Go to Cognito Console → Users
   - Ensure your test user is confirmed and enabled

### Container Won't Start

1. **Check Docker is running:**
   ```bash
   docker info
   ```

2. **View container logs:**
   ```bash
   docker-compose logs open-webui
   ```

3. **Verify environment variables:**
   ```bash
   ./scripts/local-setup.sh
   ```

### Cannot Access Ollama Models

If you're running Ollama locally and Open WebUI can't connect:

1. **Ensure Ollama is running** on your host machine

2. **Verify the Ollama URL** in `.env.local`:
   ```bash
   OLLAMA_API_BASE_URL=http://host.docker.internal:11434
   ```

3. **Test Ollama connectivity** from inside the container:
   ```bash
   docker exec -it open-webui curl http://host.docker.internal:11434/api/tags
   ```

### Database Errors

If you encounter database corruption:

1. **Stop the container:**
   ```bash
   ./scripts/stop.sh
   ```

2. **Remove the volume:**
   ```bash
   docker volume rm open-webui-data
   ```

3. **Start fresh:**
   ```bash
   ./scripts/start.sh
   ```

## Advanced Configuration

### Using Custom LLM Backends

Edit `.env.local` to configure different LLM backends:

**OpenAI:**
```bash
OPENAI_API_KEY=sk-...
OPENAI_API_BASE_URL=https://api.openai.com/v1
```

**Azure OpenAI:**
```bash
OPENAI_API_KEY=your-azure-key
OPENAI_API_BASE_URL=https://your-resource.openai.azure.com/
```

### Enabling Debug Logging

Add to `.env.local`:
```bash
LOG_LEVEL=DEBUG
```

### Custom Data Directory

To use a different data directory:

1. Update `.env.local`:
   ```bash
   DATA_DIR=/custom/path
   ```

2. Update volume mount in `docker-compose.yml` if needed

## Next Steps

- **Deploy to AWS:** See [AWS Deployment Guide](aws-deployment.md)
- **Configure Cognito:** See [Cognito Setup Guide](cognito-setup.md)
- **Troubleshooting:** See [Troubleshooting Guide](troubleshooting.md)

## Security Considerations

### Local Development

- The local setup uses HTTP (not HTTPS) for simplicity
- Cognito still uses HTTPS for authentication
- Do not expose your local instance to the internet
- Keep your `.env.local` file secure and never commit it to version control

### Production

For production deployments, always use:
- HTTPS with valid SSL certificates
- Strong passwords and MFA
- Regular security updates
- See [AWS Deployment Guide](aws-deployment.md) for production setup

## Getting Help

If you encounter issues:

1. Check the [Troubleshooting Guide](troubleshooting.md)
2. Review container logs: `./scripts/logs.sh`
3. Verify Cognito configuration in AWS Console
4. Check [Open WebUI Documentation](https://docs.openwebui.com/)
5. Review [AWS Cognito Documentation](https://docs.aws.amazon.com/cognito/)
