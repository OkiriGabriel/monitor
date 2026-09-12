#!/bin/bash
#
# Certbot Certificate Renewal Script
# This script checks and renews SSL certificates using certbot
#
# Usage: ./certbot-renew.sh [--dry-run]
#

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${SCRIPT_DIR}/logs"
LOG_FILE="${LOG_DIR}/certbot-renew-$(date +%Y%m%d).log"
CERTBOT_AUTO="/home/ec2-user/certbot-auto"
EMAIL="${CERTBOT_EMAIL:-your-email@example.com}"

# Create log directory if it doesn't exist
mkdir -p "$LOG_DIR"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Error handling
error_exit() {
    log "ERROR: $1"
    exit 1
}

# Determine which certbot to use (prefer regular certbot over certbot-auto)
if command -v certbot &> /dev/null; then
    CERTBOT_CMD="certbot"
    log "Using system certbot command"
elif [ -f "$CERTBOT_AUTO" ]; then
    CERTBOT_CMD="$CERTBOT_AUTO"
    chmod +x "$CERTBOT_CMD"
    log "Using certbot-auto (fallback)"
else
    error_exit "Neither certbot nor certbot-auto found. Please install certbot or ensure certbot-auto exists at $CERTBOT_AUTO"
fi

log "Starting certificate renewal check..."

# Determine if this is a dry run
DRY_RUN=""
if [ "$1" = "--dry-run" ]; then
    DRY_RUN="--dry-run"
    log "Running in DRY-RUN mode (no changes will be made)"
fi

log "Running certbot renewal command (this may take a few minutes)..."

# Run certbot renewal
# The 'renew' command checks all certificates and renews those that are close to expiry
# Certbot only renews certificates that are within 30 days of expiration
# Using tee to show output on screen and save to log file
if [ "$CERTBOT_CMD" = "$CERTBOT_AUTO" ]; then
    # Use certbot-auto with --no-self-upgrade
    if $CERTBOT_CMD renew $DRY_RUN \
        --non-interactive \
        --no-self-upgrade \
        --agree-tos \
        --email "$EMAIL" \
        2>&1 | tee -a "$LOG_FILE"; then
        RENEWAL_EXIT_CODE=$?
    else
        RENEWAL_EXIT_CODE=$?
    fi
else
    # Use regular certbot (no --no-self-upgrade needed)
    if $CERTBOT_CMD renew $DRY_RUN \
        --non-interactive \
        --agree-tos \
        --email "$EMAIL" \
        2>&1 | tee -a "$LOG_FILE"; then
        RENEWAL_EXIT_CODE=$?
    else
        RENEWAL_EXIT_CODE=$?
    fi
fi

if [ $RENEWAL_EXIT_CODE -eq 0 ]; then
    log "Certificate renewal check completed successfully"
    
    # Check if any certificates were actually renewed
    if grep -q "Congratulations" "$LOG_FILE" || grep -q "Successfully renewed" "$LOG_FILE" || grep -q "new certificate deployed" "$LOG_FILE"; then
        log "Certificates were renewed!"
        
        # If you're using nginx/apache, you might want to reload the web server
        # Uncomment and modify as needed:
        # systemctl reload nginx 2>/dev/null || service nginx reload 2>/dev/null
        # systemctl reload apache2 2>/dev/null || service apache2 reload 2>/dev/null
        
        # If using Docker, you might need to restart containers
        # Uncomment and modify as needed:
        # cd "$SCRIPT_DIR/../grafana-monitoring" && docker-compose restart 2>/dev/null || true
    else
        log "No certificates needed renewal (still valid)"
    fi
else
    log "Certificate renewal check completed with exit code: $RENEWAL_EXIT_CODE"
    log "Some certificates may have failed to renew. Check $LOG_FILE for details."
fi

log "Certificate renewal process finished"

# Clean up old log files (keep last 30 days)
find "$LOG_DIR" -name "certbot-renew-*.log" -type f -mtime +30 -delete 2>/dev/null || true

exit 0

