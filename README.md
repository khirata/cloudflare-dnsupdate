# Cloudflare Dynamic DNS Updater

A lightweight Bash script to automatically create or update Cloudflare DNS A/AAAA records with the external IP addresses (IPv4 and IPv6) of the machine running it. This is useful for self-hosted services running on dynamic residential connections.

It uses `ipify.org` to retrieve the current public IPs and interacts with the Cloudflare v4 API to update DNS entries. The script is smart enough to check existing records first and will only skip identical records or overwrite records it previously created (flagged via a `dnsupdater` comment field tag) to prevent accidental data loss. It also features robust IP validation and detailed API error logging.

## Initial Setup

1. **Clone the repository** (or download the script):
   ```bash
   git clone https://github.com/khirata/cloudflare-dnsupdate.git
   cd cloudflare-dnsupdate
   chmod +x cloudflare-dns-update.sh
   ```

2. **Configure your Cloudflare Credentials:**
   The script relies on a configuration file located at `~/.cloudflare`. 
   
   First, copy the template file to your home directory:
   ```bash
   cp .cloudflare.tmpl ~/.cloudflare
   ```

3. **Secure the file** so that other users on the system cannot read your API tokens:
   ```bash
   chmod 600 ~/.cloudflare
   ```

## Getting your Cloudflare API Details

You need to fill in the variables inside `~/.cloudflare`. Open it with your favorite editor (`nano ~/.cloudflare`).

### `zone` and `dnshost`
*   `zone`: This is your root domain name on Cloudflare (e.g., `example.com`).
*   `dnshost`: This is the specific subdomain (or root domain) you want to update (e.g., `home.example.com` or `example.com`).

### `cloudflare_auth_email`
This is simply the email address you use to log into your Cloudflare account.

### `cloudflare_auth_key` (API Token)
For security, **do not use your Global API Key**. Instead, generate a scoped API Token that only has permission to edit DNS records for your specific zone.

1.  Log in to the [Cloudflare Dashboard](https://dash.cloudflare.com/).
2.  Click on the user profile icon (top right) -> **My Profile** -> **API Tokens**.
3.  Click **Create Token**.
4.  Scroll down to the bottom and select **Create Custom Token**.
5.  Set the following:
    *   **Token Name:** e.g., "DDNS Updater"
    *   **Permissions:** Select `Zone`, then `DNS`, then `Edit`
    *   **Zone Resources:** Select `Include`, then `Specific zone`, then select your `zone` (e.g., example.com)
6.  Click **Continue to summary**, then **Create Token**.
7.  **Copy the generated string** and paste it into `cloudflare_auth_key` inside `~/.cloudflare`.

Your finalized `~/.cloudflare` should look something like this:
```env
# configuration used by cloudflare-dns-update.sh
zone=example.com
dnshost=home.example.com
cloudflare_auth_email=your.email@gmail.com
cloudflare_auth_key=abc123DEF456ghi789...
```

## Running the Script

You can run it manually at any time to verify it's working:
```bash
./cloudflare-dns-update.sh
```

You should see output similar to this:
```
2026-03-03T11:00:00-0800 Establishing connection as IPv4 (203.0.113.50) and IPv6 (2001:db8::1)
2026-03-03T11:00:01-0800 A: Creating record (203.0.113.50)
2026-03-03T11:00:01-0800 Success: Created ID 1a2b3c4d5e6f
2026-03-03T11:00:02-0800 AAAA: home.example.com is currently set to 2001:db8::1; no changes needed
```

## Automating with a Cronjob

To make this a true Dynamic DNS solution, you need to configure your system to run this script automatically on a regular schedule (e.g., every 5 minutes).

Open your crontab editor:
```bash
crontab -e
```

Add the following line to the bottom of the file. Adjust the path to match wherever you cloned the script:

```cron
# Update Cloudflare DNS A/AAAA records every day (at midnight)
0 0 * * * /path/to/your/cloudflare-dnsupdate/cloudflare-dns-update.sh >> /tmp/cloudflare-dns-update.log 2>&1
```

*Note: The `>> /tmp/cloudflare-dns-update.log 2>&1` part tells cron to append any output or errors to a log file instead of emailing it to the local user account, which makes debugging much easier.*
