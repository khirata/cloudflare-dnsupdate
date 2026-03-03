#!/bin/bash

# A bash script to create/update a Cloudflare DNS A/AAAA record with the external IP of the source machine

## Set environment variables (see .cloudflare.tmpl)
# zone : Cloudflare zone (e.g. yourdomain.com)
# dnshost: hostname of the A/AAAA record (e.g. yourhost.yourdomain.com)
# cloudflare_auth_email : Cloudflare username
# cloudflare_auth_key : API Token (e.g. Zone: yourdomain.com, Permissions: Zone.DNS.Edit)
source ~/.cloudflare

# A/AAAA record with "dnsupdater" in comment field is updated (Note: tag field is not available for free tier)
tag="dnsupdater"

# Helper function for logging with ISO-8601 timestamp
log() {
    echo "$(date +"%Y-%m-%dT%H:%M:%S%z") $*"
}

# Helper function to validate an IP address
validate_ip() {
    local ip=$1
    local type=$2

    if [ -z "$ip" ]; then
        return 1
    fi

    if [[ "$type" == "A" ]]; then
        # IPv4 regex validation
        if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
            return 0
        fi
    elif [[ "$type" == "AAAA" ]]; then
        # Basic IPv6 regex validation
        if [[ $ip =~ ^([0-9a-fA-F]{0,4}:){1,7}[0-9a-fA-F]{0,4}$ ]]; then
            return 0
        fi
    fi
    return 1
}

# Helper function to query Cloudflare API
cloudflare_api() {
    local method=$1
    local endpoint=$2
    shift 2

    # $@ now contains the optional --data arguments
    curl -s -X "$method" "https://api.cloudflare.com/client/v4/$endpoint" \
         -H "X-Auth-Email: $cloudflare_auth_email" \
         -H "Authorization: Bearer $cloudflare_auth_key" \
         -H "Content-Type: application/json" "$@"
}

# Helper function to handle record creation/updating
update_record() {
    local type=$1    # "A" or "AAAA"
    local ip=$2      # The IP address
    local zoneid=$3  # Zone ID

    # Validation
    if ! validate_ip "$ip" "$type"; then
        if [ "$type" == "AAAA" ] && [ -z "$ip" ]; then
           log "This host does not have a public IPv6 address"
           return 0
        fi
        log "Error: Invalid $type IP address received: '$ip'"
        return 1
    fi

    # Lookup existing record filtered by comment
    local response=$(cloudflare_api GET "zones/$zoneid/dns_records?type=$type&name=$dnshost&comment=$tag")
    
    # Check if API request was successful
    local success=$(echo "$response" | jq -r '.success')
    if [[ "$success" != "true" ]]; then
        log "Error: Failed to fetch $type record for $dnshost from Cloudflare."
        log "API Response: $response"
        return 1
    fi

    # Parse details
    local dnsrecord=$(echo "$response" | jq -r '.result[0] // empty')
    local dnsrecordid=$(echo "$dnsrecord" | jq -r '.id // empty')
    local dnsip=$(echo "$dnsrecord" | jq -r '.content // empty')

    if [[ "$ip" == "$dnsip" ]]; then
        log "$type: $dnshost is currently set to $ip; no changes needed"
    else
        local body="{\"type\":\"$type\",\"name\":\"$dnshost\",\"content\":\"$ip\",\"ttl\":1,\"proxied\":false,\"comment\":\"$tag\"}"

        if [[ -z "$dnsrecordid" || "$dnsrecordid" == "null" ]]; then
            # Create the record
            log "$type: Creating record ($ip)"
            local post_response=$(cloudflare_api POST "zones/$zoneid/dns_records" --data "$body")
            local post_success=$(echo "$post_response" | jq -r '.success')
            if [[ "$post_success" != "true" ]]; then
                log "Error: Failed to create $type record."
                log "API Response: $post_response"
                return 1
            fi
            log "$(echo "$post_response" | jq -r '.result | "Success: Created ID \(.id)"')"
        else
            # Update the record
            log "$type: Updating record ($dnsip -> $ip)"
            local put_response=$(cloudflare_api PUT "zones/$zoneid/dns_records/$dnsrecordid" --data "$body")
            local put_success=$(echo "$put_response" | jq -r '.success')
             if [[ "$put_success" != "true" ]]; then
                log "Error: Failed to update $type record."
                log "API Response: $put_response"
                return 1
            fi
            log "$(echo "$put_response" | jq -r '.result | "Success: Updated \(.name) to \(.content)"')"
        fi
    fi
}

# --- Main Execution ---

# Get the current external IP addresses
ipv4=$(curl -s api.ipify.org)
ipv6=$(curl -s api6.ipify.org)

log "Establishing connection as IPv4 ($ipv4) and IPv6 ($ipv6)"

# Get the zone ID
zone_response=$(cloudflare_api GET "zones?name=$zone&status=active")
zone_success=$(echo "$zone_response" | jq -r '.success')

if [[ "$zone_success" != "true" ]]; then
    log "Error: Failed to retrieve Zone ID for $zone"
    log "API Response: $zone_response"
    exit 1
fi

zoneid=$(echo "$zone_response" | jq -r '.result[0].id // empty')

if [[ -z "$zoneid" || "$zoneid" == "null" ]]; then
     log "Error: Zone ID for $zone is empty. Check your zone name and API credentials."
     exit 1
fi

# Process records
update_record "A" "$ipv4" "$zoneid"
update_record "AAAA" "$ipv6" "$zoneid"

exit 0
