# Certbot Certificate Renewal - Cron Job Setup Guide

This guide explains how to set up automatic certificate renewal using cron.

## Prerequisites

1. Certbot-auto script should be at `/home/ec2-user/certbot-auto`
2. The renewal script (`certbot-renew.sh`) should be executable and located at `/home/ec2-user/monitoring/cert-automation/certbot-renew.sh`
3. You need root/sudo access to set up the cron job

## Quick Setup

### Step 1: Update Email in Renewal Script

Edit `certbot-renew.sh` and update the email address:

```bash
EMAIL="your-email@example.com"  # Change this to your email
```

### Step 2: Test the Renewal Script

Before setting up cron, test the script manually:

```bash
# Test with dry-run (no actual changes)
./certbot-renew.sh --dry-run

# Test actual renewal (if certificates are close to expiry)
./certbot-renew.sh
```

### Step 3: Set Up Cron Job

#### Option A: Using crontab (Recommended)

1. Open crontab editor:
   ```bash
   sudo crontab -e
   ```

2. Add one of the following entries:

   **Twice daily check (recommended):**
   ```cron
   # Check for certificate renewal twice daily at 2 AM and 2 PM
   0 2,14 * * * /home/ec2-user/certbot-renew.sh >> /home/ec2-user/logs/certbot-cron.log 2>&1
   ```

   **Daily check:**
   ```cron
   # Check for certificate renewal daily at 2 AM
   0 2 * * * /home/ec2-user/certbot-renew.sh >> /home/ec2-user/logs/certbot-cron.log 2>&1
   ```

   **Weekly check:**
   ```cron
   # Check for certificate renewal weekly on Sunday at 2 AM
   0 2 * * 0 /home/ec2-user/certbot-renew.sh >> /home/ec2-user/monitoring/cert-automation/logs/certbot-cron.log 2>&1
   ```

#### Option B: Using Systemd Timer (Linux systems)

Create a systemd service and timer for more advanced scheduling:

1. Create service file: `/etc/systemd/system/certbot-renew.service`
   ```ini
   [Unit]
   Description=Certbot Certificate Renewal
   After=network.target

   [Service]
   Type=oneshot
   ExecStart=/home/ec2-user/monitoring/cert-automation/certbot-renew.sh
   User=root
   ```

2. Create timer file: `/etc/systemd/system/certbot-renew.timer`
   ```ini
   [Unit]
   Description=Run Certbot renewal twice daily
   Requires=certbot-renew.service

   [Timer]
   OnCalendar=*-*-* 02,14:00:00
   Persistent=true

   [Install]
   WantedBy=timers.target
   ```

3. Enable and start the timer:
   ```bash
   sudo systemctl enable certbot-renew.timer
   sudo systemctl start certbot-renew.timer
   sudo systemctl status certbot-renew.timer
   ```

## Cron Schedule Examples

| Schedule | Cron Expression | Description |
|----------|----------------|-------------|
| Twice daily | `0 2,14 * * *` | 2 AM and 2 PM every day |
| Daily | `0 2 * * *` | 2 AM every day |
| Weekly | `0 2 * * 0` | 2 AM every Sunday |
| Monthly | `0 2 1 * *` | 2 AM on the 1st of every month |
| Every 12 hours | `0 */12 * * *` | Every 12 hours |

## Important Notes

1. **Certbot Auto-Renewal**: Certbot only renews certificates that are within 30 days of expiration. Running it more frequently is safe but won't cause unnecessary renewals.

2. **Web Server Reload**: If you're using nginx or apache, you may need to reload them after renewal. Uncomment the relevant lines in `certbot-renew.sh`.

3. **Docker Services**: If certificates are used by Docker containers, you may need to restart them. Uncomment and modify the Docker restart section in `certbot-renew.sh`.

4. **Logs**: Logs are stored in `logs/certbot-renew-YYYYMMDD.log` and automatically cleaned up after 30 days.

5. **Email Notifications**: Consider setting up email alerts for renewal failures. You can modify the script to send emails on errors.

## Troubleshooting

### Check if cron job is running:
```bash
# View cron logs (location varies by system)
sudo grep CRON /var/log/syslog
# or
sudo journalctl -u cron
```

### Test cron job manually:
```bash
# Run the script with full path
/home/ec2-user/monitoring/cert-automation/certbot-renew.sh --dry-run
```

### Verify cron job is scheduled:
```bash
sudo crontab -l
```

### Check certificate expiration:
```bash
/home/ec2-user/certbot-auto certificates
```

## Security Considerations

1. The cron job should run as root (or a user with appropriate permissions)
2. Keep the certbot-auto script secure at `/home/ec2-user/certbot-auto` (it should only be writable by root)
3. Review logs regularly for any issues
4. Consider setting up monitoring/alerting for renewal failures

## Additional Resources

- [Certbot Documentation](https://certbot.eff.org/docs/)
- [Let's Encrypt Community](https://community.letsencrypt.org/)

