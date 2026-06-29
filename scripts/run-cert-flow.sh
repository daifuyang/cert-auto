#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${SCRIPT_DIR}/../config"

usage() {
  echo "Usage: $0 [--dry-run] [--domain DOMAIN] [--profile PROFILE] [--fc-domain DOMAIN]"
  echo ""
  echo "Options:"
  echo "  --dry-run       Show what would be done without making changes"
  echo "  --domain        Domain to issue certificate for. Repeat for SAN certificates."
  echo "  --profile       Aliyun profile name for DNS and CAS. Defaults to AIC config default."
  echo "  --fc-domain     FC custom domain to update after CAS upload. Repeat as needed."
  echo "  --fc-region     FC region. Defaults to cn-shanghai."
  echo "  --renew-days    Renew only if the current certificate expires within N days."
  echo "  --force         Issue and upload even if the current certificate is not expiring."
  echo "  --help          Show this help message"
  exit 1
}

DRY_RUN=false
DOMAINS=()
FC_DOMAINS=()
PROFILE=""
FC_REGION="cn-shanghai"
RENEW_DAYS=""
FORCE=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --domain)
      DOMAINS+=("$2")
      shift 2
      ;;
    --profile)
      PROFILE="$2"
      shift 2
      ;;
    --fc-domain)
      FC_DOMAINS+=("$2")
      shift 2
      ;;
    --fc-region)
      FC_REGION="$2"
      shift 2
      ;;
    --renew-days)
      RENEW_DAYS="$2"
      shift 2
      ;;
    --force)
      FORCE=true
      shift
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

if [ -f "${CONFIG_DIR}/domains.env" ]; then
  # shellcheck disable=SC1091
  source "${CONFIG_DIR}/domains.env"
fi

if [ "${#DOMAINS[@]}" -eq 0 ] && [ -n "${CERT_DOMAINS:-}" ]; then
  read -r -a DOMAINS <<< "$CERT_DOMAINS"
fi

if [ "${#DOMAINS[@]}" -eq 0 ] && [ -n "${CERT_DOMAIN:-}" ]; then
  DOMAINS+=("$CERT_DOMAIN")
fi

if [ "${#FC_DOMAINS[@]}" -eq 0 ] && [ -n "${FC_CUSTOM_DOMAINS:-}" ]; then
  read -r -a FC_DOMAINS <<< "$FC_CUSTOM_DOMAINS"
fi

if [ -z "$PROFILE" ] && [ -n "${ALIYUN_PROFILE:-}" ]; then
  PROFILE="$ALIYUN_PROFILE"
fi

if [ -n "${ALIYUN_FC_REGION:-}" ]; then
  FC_REGION="$ALIYUN_FC_REGION"
fi

if [ "${#DOMAINS[@]}" -eq 0 ]; then
  echo "Error: DOMAIN not specified and no config found"
  usage
fi

primary_domain="${DOMAINS[0]}"

echo "============================================"
echo "Cert Auto Flow"
echo "============================================"
echo "Domains:     ${DOMAINS[*]}"
echo "Profile:     ${PROFILE:-default}"
echo "FC domains:  ${FC_DOMAINS[*]:-none}"
echo "FC region:   $FC_REGION"
echo "Renew days:  ${RENEW_DAYS:-none}"
echo "Force:       $FORCE"
echo "Dry-run:     $DRY_RUN"
echo "============================================"

if [ -n "$RENEW_DAYS" ] && [ "$FORCE" != true ]; then
  echo ""
  echo "[0/3] Checking current certificate expiry..."
  cert_end_date=$(
    echo | openssl s_client -connect "${primary_domain}:443" -servername "$primary_domain" 2>/dev/null \
      | openssl x509 -noout -enddate 2>/dev/null \
      | cut -d= -f2- || true
  )

  if [ -n "$cert_end_date" ]; then
    cert_end_epoch=$(date -d "$cert_end_date" +%s)
    now_epoch=$(date +%s)
    days_left=$(( (cert_end_epoch - now_epoch) / 86400 ))
    echo "Current certificate expires in ${days_left} day(s): $cert_end_date"

    if [ "$days_left" -gt "$RENEW_DAYS" ]; then
      echo "Certificate is not within renewal window. Nothing to do."
      exit 0
    fi
  else
    echo "Could not read current certificate. Continuing with renewal."
  fi
fi

if [ "$DRY_RUN" = true ]; then
  echo ""
  echo "[1/3] Would issue certificate via ACME DNS-01 (Aliyun)."
  echo "[2/3] Would upload certificate to Aliyun CAS."
  if [ "${#FC_DOMAINS[@]}" -eq 0 ]; then
    echo "[3/3] No FC custom domains configured."
  else
    echo "[3/3] Would update FC custom domains: ${FC_DOMAINS[*]}"
  fi
  echo ""
  echo "Dry-run complete. No changes made."
  exit 0
fi

echo ""
echo "[1/3] Issuing certificate via ACME DNS-01 (Aliyun)..."
issue_cmd=(aic cert:issue -d aliyun)
if [ -n "$PROFILE" ]; then
  issue_cmd+=(-p "$PROFILE")
fi
issue_cmd+=("${DOMAINS[@]}")
issue_output=$("${issue_cmd[@]}" 2>&2)
echo "$issue_output"

cert_path=$(echo "$issue_output" | jq -r '.certPath // empty')
key_path=$(echo "$issue_output" | jq -r '.keyPath // empty')

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

echo ""
echo "[2/3] Uploading certificate to Aliyun CAS..."
cert_name="${CERT_NAME_PREFIX:-$primary_domain}-$(date +%Y%m%d)"
upload_cmd=(aic aliyun-cert:upload "$cert_name" "$cert_path" "$key_path")
if [ -n "$PROFILE" ]; then
  upload_cmd+=(-p "$PROFILE")
fi
upload_output=$("${upload_cmd[@]}" 2>&1)
echo "$upload_output"

cert_id=$(echo "$upload_output" | jq -r '.certId // empty')
success=$(echo "$upload_output" | jq -r '.success // false')

if [ "$success" != "true" ]; then
  echo "Error: Upload failed"
  exit 1
fi

echo ""
echo "[3/3] Updating FC custom domains..."
echo "Certificate ID: $cert_id"

if [ "${#FC_DOMAINS[@]}" -eq 0 ]; then
  echo "No FC custom domains configured. CAS upload complete."
else
  for fc_domain in "${FC_DOMAINS[@]}"; do
    echo "Updating FC custom domain: $fc_domain"
    current_domain=$(aliyun fc GetCustomDomain \
      --region "$FC_REGION" \
      --domainName "$fc_domain")

    update_body=$(echo "$current_domain" | jq --arg cert_name "cret-$cert_id" '{
      protocol,
      certConfig: { certName: $cert_name },
      routeConfig,
      wafConfig
    }')

    aliyun fc UpdateCustomDomain \
      --region "$FC_REGION" \
      --domainName "$fc_domain" \
      --body "$update_body" >/dev/null
  done
fi

echo ""
echo "============================================"
echo "Complete!"
echo "============================================"
