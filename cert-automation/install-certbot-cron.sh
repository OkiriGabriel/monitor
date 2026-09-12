#!/bin/bash
#
# Install Certbot Renewal Cron Job
# This script helps you set up the cron job for automatic certificate renewal
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RENEWAL_SCRIPT="${SCRIPT_DIR}/certbot-renew.sh"
CRON_LOG="${SCRIPT_DIR}/logs/certbot-cron.log"

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "This script needs to be run with sudo/root privileges"
    echo "Usage: sudo ./install-certbot-cron.sh"
    exit 1
fi

# Check if renewal script exists
if [ ! -f "$RENEWAL_SCRIPT" ]; then
    echo "Error: certbot-renew.sh not found at $RENEWAL_SCRIPT"
    exit 1
fi

# Make sure renewal script is executable
chmod +x "$RENEWAL_SCRIPT"

# Create logs directory
mkdir -p "${SCRIPT_DIR}/logs"

echo "Certbot Renewal Cron Job Installer"
echo "==================================="
echo ""
echo "Project directory: $SCRIPT_DIR"
echo "Renewal script: $RENEWAL_SCRIPT"
echo ""

# Ask for schedule preference
echo "Select renewal schedule:"
echo "1) Twice daily (2 AM and 2 PM) - Recommended"
echo "2) Daily (2 AM)"
echo "3) Weekly (Sunday 2 AM)"
echo "4) Custom (you'll edit crontab manually)"
read -p "Enter choice [1-4]: " choice

case $choice in
    1)
        CRON_SCHEDULE="0 2,14 * * *"
        SCHEDULE_DESC="twice daily at 2 AM and 2 PM"
        ;;
    2)
        CRON_SCHEDULE="0 2 * * *"
        SCHEDULE_DESC="daily at 2 AM"
        ;;
    3)
        CRON_SCHEDULE="0 2 * * 0"
        SCHEDULE_DESC="weekly on Sunday at 2 AM"
        ;;
    4)
        echo ""
        echo "To set up a custom schedule, run:"
        echo "  sudo crontab -e"
        echo ""
        echo "And add this line (modify the schedule as needed):"
        echo "  0 2 * * * $RENEWAL_SCRIPT >> $CRON_LOG 2>&1"
        echo ""
        exit 0
        ;;
    *)
        echo "Invalid choice. Exiting."
        exit 1
        ;;
esac

# Create cron entry
CRON_ENTRY="$CRON_SCHEDULE $RENEWAL_SCRIPT >> $CRON_LOG 2>&1"

echo ""
echo "Schedule: $SCHEDULE_DESC"
echo "Cron entry: $CRON_ENTRY"
echo ""

# Check if cron entry already exists
if crontab -l 2>/dev/null | grep -q "$RENEWAL_SCRIPT"; then
    echo "Warning: A cron job for certbot renewal already exists!"
    echo ""
    echo "Current crontab entries:"
    crontab -l | grep -E "(certbot|certbot-renew)" || true
    echo ""
    read -p "Do you want to replace it? [y/N]: " replace
    if [[ ! "$replace" =~ ^[Yy]$ ]]; then
        echo "Installation cancelled."
        exit 0
    fi
    
    # Remove existing entry
    crontab -l 2>/dev/null | grep -v "$RENEWAL_SCRIPT" | crontab - 2>/dev/null || true
fi

# Add new cron entry
(crontab -l 2>/dev/null; echo "$CRON_ENTRY") | crontab -

echo ""
echo "✓ Cron job installed successfully!"
echo ""
echo "The certificate renewal will run $SCHEDULE_DESC"
echo "Logs will be written to: $CRON_LOG"
echo ""
echo "To verify the installation:"
echo "  sudo crontab -l"
echo ""
echo "To test the renewal script:"
echo "  $RENEWAL_SCRIPT --dry-run"
echo ""
echo "To view logs:"
echo "  tail -f $CRON_LOG"
echo ""

