# Setup Guide

## Prerequisites

1. **aic CLI** installed globally (`npm install -g @zerocmf/aic`)
2. **Aliyun DNS** account with API access
3. **Aliyun CAS** (Certificate Authority Service) access
4. **GitHub repository** to host this project

## Local Setup

### 1. Install aic CLI

```bash
npm install -g @zerocmf/aic@latest
aic --version
```

### 2. Configure Aliyun Credentials

Create `~/.config/aic/config.toml`:

```toml
[aliyun]
accessKeyId = "your-access-key-id"
accessKeySecret = "your-access-key-secret"
```

### 3. Configure Domain

Copy and edit the config:

```bash
cp config/domains.env.example config/domains.env
# Edit config/domains.env with your domain
```

### 4. Test Locally

```bash
# Dry-run first
./scripts/run-cert-flow.sh --dry-run --domain static.zerocmf.com

# Full flow
./scripts/run-cert-flow.sh --domain static.zerocmf.com
```

## GitHub Actions Setup

### 1. Add Secrets

In your GitHub repository, go to **Settings → Secrets and variables → Actions** and add:

| Secret Name | Description |
|-------------|-------------|
| `ALIYUN_ACCESS_KEY_ID` | Aliyun Access Key ID |
| `ALIYUN_ACCESS_KEY_SECRET` | Aliyun Access Key Secret |

### 2. Add Domain Config

Create `config/domains.env` in your repository (do NOT commit the real value):

```env
CERT_DOMAIN=static.zerocmf.com
```

Add to GitHub repo as a **variable** (not secret):
- Name: `CERT_DOMAIN`
- Value: `static.zerocmf.com`

### 3. Enable Workflow

Push to main branch or manually trigger:

```bash
git add .
git commit -m "feat: add cert-auto project"
git push
```

Or trigger manually from **Actions → Cert Auto Issue & Upload → Run workflow**.

## Workflow Triggers

- **Manual**: Click "Run workflow" in GitHub Actions
- **Scheduled**: Daily at 03:00 UTC (cron: `0 3 * * *`)

## Dry-run Mode

Use `--dry-run` input when triggering manually to verify the flow without uploading.
