#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${SCRIPT_DIR}/../config"

usage() {
  echo "Usage: $0 [--dry-run] [--domain DOMAIN]"
  echo ""
  echo "Options:"
  echo "  --dry-run    Show what would be done without making changes"
  echo "  --domain     Specify domain to issue certificate for"
  echo "  --help       Show this help message"
  exit 1
}

DRY_RUN=false
DOMAIN=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --domain)
      DOMAIN="$2"
      shift 2
      ;;
    --help)
      usage
      ;;
    *)
      echo "Unknown option: $1"
      usage
      ;;
  esac
done

if [ -z "$DOMAIN" ]; then
  if [ -f "${CONFIG_DIR}/domains.env" ]; then
    source "${CONFIG_DIR}/domains.env"
  fi
fi

if [ -z "$DOMAIN" ]; then
  echo "Error: DOMAIN not specified and no config found"
  usage
fi

echo "============================================"
echo "Cert Auto Flow"
echo "============================================"
echo "Domain:   $DOMAIN"
echo "Dry-run:  $DRY_RUN"
echo "============================================"

echo ""
echo "[1/3] Issuing certificate via ACME DNS-01 (Aliyun)..."
issue_output=$(aic cert:issue -d aliyun "$DOMAIN" 2>&2)
echo "$issue_output"

cert_path=$(echo "$issue_output" | sed -n 's/.*"certPath": "\([^"]*\)".*/\1/p')
key_path=$(echo "$issue_output" | sed -n 's/.*"keyPath": "\([^"]*\)".*/\1/p')

if [ -z "$cert_path" ] || [ ! -f "$cert_path" ]; then
  echo "Error: Certificate file not found at $cert_path"
  exit 1
fi

if [ -z "$key_path" ] || [ ! -f "$key_path" ]; then
  echo "Error: Key file not found at $key_path"
  exit 1
fi

echo ""
echo "Certificate path: $cert_path"
echo "Key path: $key_path"

if [ "$DRY_RUN" = true ]; then
  echo ""
  echo "[2/3] Skipping upload (dry-run mode)"
  echo "[3/3] Skipping Aliyun CAS verification (dry-run mode)"
  echo ""
  echo "Dry-run complete. No changes made."
  exit 0
fi

echo ""
echo "[2/3] Uploading certificate to Aliyun CAS..."
cert_name="${DOMAIN}-$(date +%Y%m%d)"
upload_output=$(aic aliyun-cert:upload "$cert_name" "$cert_path" "$key_path" 2>&1)
echo "$upload_output"

cert_id=$(echo "$upload_output" | sed -n 's/.*"certId": "\([^"]*\)".*/\1/p')
success=$(echo "$upload_output" | sed -n 's/.*"success": \([a-z]*\).*/\1/p')

if [ "$success" != "true" ]; then
  echo "Error: Upload failed"
  exit 1
fi

echo ""
echo "[3/3] Verifying upload..."
echo "Certificate ID: $cert_id"
echo ""
echo "Certificate details:"
aic aliyun-cert:info "$cert_id"

echo ""
echo "Current certificates in Aliyun CAS:"
aic aliyun-cert:list

echo ""
echo "============================================"
echo "Complete!"
echo "============================================"
