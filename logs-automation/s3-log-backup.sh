#!/bin/bash

# Configuration — set these via environment or edit before running
LOG_DIR="${LOG_DIR:-/var/www/html/app/storage/logs}"
S3_BUCKET="${S3_BUCKET:-your-bucket-name}"
S3_PATH="${S3_PATH:-app-logs}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Create a timestamped archive name
ARCHIVE_NAME="app_logs_${TIMESTAMP}.tar.gz"
TEMP_ARCHIVE="/tmp/${ARCHIVE_NAME}"

# Log function
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log_message "Starting log backup process..."

# Check if log directory exists
if [ ! -d "$LOG_DIR" ]; then
    log_message "ERROR: Log directory $LOG_DIR does not exist"
    exit 1
fi

# Check if there are any files to archive
if [ -z "$(ls -A $LOG_DIR)" ]; then
    log_message "No log files found in $LOG_DIR"
    exit 0
fi

# Create compressed archive of logs
log_message "Creating archive: $ARCHIVE_NAME"
tar -czf "$TEMP_ARCHIVE" -C "$LOG_DIR" . 2>/dev/null

if [ $? -ne 0 ]; then
    log_message "ERROR: Failed to create archive"
    exit 1
fi

# Upload to S3
log_message "Uploading to S3: s3://${S3_BUCKET}/${S3_PATH}/${ARCHIVE_NAME}"
# Use specific profile if needed: --profile your-profile-name
aws s3 cp "$TEMP_ARCHIVE" "s3://${S3_BUCKET}/${S3_PATH}/${ARCHIVE_NAME}"

if [ $? -eq 0 ]; then
    log_message "Successfully uploaded to S3"
    
    # Delete local log files after successful upload
    log_message "Cleaning up local log files..."
    find "$LOG_DIR" -type f -name "*.log" -delete
    find "$LOG_DIR" -type f -name "*.log.*" -delete
    
    log_message "Local log files deleted"
else
    log_message "ERROR: Failed to upload to S3"
    rm -f "$TEMP_ARCHIVE"
    exit 1
fi

# Remove temporary archive
rm -f "$TEMP_ARCHIVE"
log_message "Backup process completed successfully"

exit 0