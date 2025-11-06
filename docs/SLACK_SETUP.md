# Setting Up Slack Notifications

This guide will help you configure Slack notifications for your Cosmos Hub validator.

## Step 1: Create a Slack Workspace (if you don't have one)

1. Go to https://slack.com/create
2. Follow the prompts to create a new workspace
3. Choose a workspace name (e.g., "My Validator Monitoring")

## Step 2: Create a Slack App and Webhook

### Option A: Using Incoming Webhooks (Recommended - Easiest)

1. **Go to the Slack App Directory:**
   - Visit: https://api.slack.com/apps

2. **Create a New App:**
   - Click "Create New App"
   - Select "From scratch"
   - App Name: "Cosmos Validator Alerts" (or any name you prefer)
   - Select your workspace from the dropdown
   - Click "Create App"

3. **Enable Incoming Webhooks:**
   - In the left sidebar, click "Incoming Webhooks"
   - Toggle "Activate Incoming Webhooks" to ON
   - Click "Add New Webhook to Workspace"
   - Select the channel where you want alerts (create `#cosmos-validator-alerts` if needed)
   - Click "Allow"

4. **Copy Your Webhook URL:**
   - You'll see a webhook URL that looks like:
     ```
     https://hooks.slack.com/services/T00000000/B00000000/XXXXXXXXXXXXXXXXXXXX
     ```
   - **Copy this URL** - you'll need it in the next step

### Option B: Using a Slack Bot (More Features)

1. Visit https://api.slack.com/apps
2. Click "Create New App" → "From scratch"
3. Name it "Cosmos Validator Bot"
4. Select your workspace
5. Go to "OAuth & Permissions"
6. Add these scopes under "Bot Token Scopes":
   - `chat:write`
   - `chat:write.public`
7. Click "Install to Workspace"
8. Copy the "Bot User OAuth Token" (starts with `xoxb-`)

## Step 3: Configure Alertmanager

1. **Edit the Alertmanager configuration:**
   ```bash
   cd /Users/seb3point0/dev/cosmos-validator
   nano alertmanager/alertmanager.yml
   ```

2. **Uncomment and set the webhook URL:**
   Find this line:
   ```yaml
   # slack_api_url: 'https://hooks.slack.com/services/YOUR/WEBHOOK/URL'
   ```
   
   Change it to (remove the `#` and replace with your URL):
   ```yaml
   slack_api_url: 'https://hooks.slack.com/services/T00000000/B00000000/XXXXXXXXXXXXXXXXXXXX'
   ```

3. **Uncomment the Slack receiver configurations:**
   Scroll down and uncomment the `slack_configs` sections for each receiver you want to enable:
   
   ```yaml
   - name: 'slack-critical'
     slack_configs:  # <- Remove the # from this and all lines below
       - channel: '#cosmos-validator-alerts'
         username: 'Cosmos Validator Monitor'
         icon_emoji: ':rotating_light:'
         color: 'danger'
         title: '🚨 CRITICAL: {{ .GroupLabels.alertname }}'
         text: >-
           {{ range .Alerts }}
             *Alert:* {{ .Annotations.summary }}
             *Description:* {{ .Annotations.description }}
             *Instance:* {{ .Labels.instance }}
             *Started:* {{ .StartsAt.Format "2006-01-02 15:04:05 MST" }}
           {{ end }}
         send_resolved: true
   ```
   
   Do the same for `slack-warnings` and `slack-info`.

4. **Save the file** (Ctrl+O, Enter, Ctrl+X in nano)

## Step 4: Restart Alertmanager

```bash
cd /Users/seb3point0/dev/cosmos-validator
docker-compose restart alertmanager
```

## Step 5: Test Your Configuration

1. **Check Alertmanager logs:**
   ```bash
   docker logs alertmanager --tail 20
   ```
   
   You should see: "Completed loading of configuration file"

2. **View Alertmanager UI:**
   Open http://localhost:9093 in your browser

3. **Send a test alert manually:**
   ```bash
   curl -XPOST http://localhost:9093/api/v1/alerts -d '[{
     "labels": {
       "alertname": "TestAlert",
       "severity": "warning",
       "instance": "test-instance"
     },
     "annotations": {
       "summary": "This is a test alert",
       "description": "Testing Slack notifications for Cosmos Validator"
     }
   }]'
   ```

4. **Check your Slack channel** - you should receive the test alert!

## Step 6: Customize Alert Channels (Optional)

You can send different alert types to different channels:

```yaml
- name: 'slack-critical'
  slack_configs:
    - channel: '#critical-alerts'    # <- Change channel
      username: 'Cosmos Validator Monitor'
      icon_emoji: ':rotating_light:'
      color: 'danger'
      ...

- name: 'slack-warnings'
  slack_configs:
    - channel: '#warnings'           # <- Different channel for warnings
      ...

- name: 'slack-info'
  slack_configs:
    - channel: '#info-feed'          # <- Different channel for info
      ...
```

## Troubleshooting

### "invalid_token" or "channel_not_found"

- Make sure your webhook URL is correct
- Verify the channel exists and the bot has access to it
- Try reinstalling the Slack app to your workspace

### No alerts received

1. Check Alertmanager logs:
   ```bash
   docker logs alertmanager
   ```

2. Verify Prometheus is sending alerts:
   - Go to http://localhost:9091/alerts
   - Check if any alerts are firing

3. Check Alertmanager UI:
   - Go to http://localhost:9093
   - Look for active alerts

4. Verify your webhook:
   ```bash
   curl -X POST -H 'Content-type: application/json' \
     --data '{"text":"Hello, World!"}' \
     YOUR_WEBHOOK_URL
   ```

### Configuration errors

Check the syntax of your YAML file:
```bash
docker exec alertmanager /bin/alertmanager --config.file=/etc/alertmanager/alertmanager.yml --config.file.check
```

## Alert Types You'll Receive

Once configured, you'll receive Slack notifications for:

### 🚨 Critical Alerts (Immediate)
- Validator node down
- High memory usage (>90%)
- Consensus failure
- Too many peers disconnected

### ⚠️ Warning Alerts (Grouped)
- Moderate memory usage (>80%)
- High CPU usage
- Slow block production
- Peer connection issues

### ℹ️ Info Alerts (Daily summary)
- New delegations
- Chain upgrades available
- Node health reports

## Security Notes

⚠️ **Important:**
- Never commit your webhook URL to version control
- Keep your `.env` file secure
- Consider using Slack's IP whitelist feature for additional security
- Rotate your webhook URL if it's ever exposed

## Additional Resources

- [Slack API Documentation](https://api.slack.com/messaging/webhooks)
- [Alertmanager Configuration Guide](https://prometheus.io/docs/alerting/latest/configuration/)
- [Cosmos Hub Validator Guide](https://hub.cosmos.network/validators/overview.html)

---

**Need Help?**
- Check the logs: `docker logs alertmanager -f`
- View active alerts: http://localhost:9093
- Test your configuration: Use the curl command in Step 5

