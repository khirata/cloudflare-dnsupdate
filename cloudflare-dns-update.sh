#!/bin/bash

# A bash script to create/update a Cloudflare DNS A/AAAA record with the external IP of the source machine

## Set environment variables (see .cloudflare.tmpl)
# zone : Cloudflare zone (e.g. yourdomain.com)
# dnshost: hostname of the A/AAAA record (e.g. yourhost.yourdomain.com)
# cloudflare_auth_email : Cloudflare username
# cloudflare_auth_key : API Token (e.g. Zone: yourdomain.com, Permissions: Zone.DNS.Edit)
source ~/.cloudflare

# Get the current external IP address
ipv4=$(curl -s api.ipify.org)
ipv6=$(curl -s api6.ipify.org)

echo "Establishing connection as IPv4 ($ipv4) and IPv6 ($ipv6)"

# A/AAAA record with "dnsupdater" in comment field is updated (Note: tag field is not available for free tier)
tag="dnsupdater"

# get the zone id for the requested zone
zoneid=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$zone&status=active" \
              -H "X-Auth-Email: $cloudflare_auth_email" \
              -H "Authorization: Bearer $cloudflare_auth_key" \
              -H "Content-Type: application/json" | jq -r '{"result"}[] | .[0] | .id')

# IPv4 : get A record
dnsrecord=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$zoneid/dns_records?type=A&name=$dnshost&comment=$tag" \
		 -H "X-Auth-Email: $cloudflare_auth_email" \
		 -H "Authorization: Bearer $cloudflare_auth_key" \
		 -H "Content-Type: application/json" | jq -r '{"result"}[] | .[0]')

dnsrecordid=$(echo $dnsrecord | jq -r .id)
dnsv4=$(echo $dnsrecord | jq -r .content)

if [[ "$ipv4" == "$dnsv4" ]]; then
    echo "IPv4: $dnshost is currently set to $ipv4; no changes needed"
else

    body="{\"type\":\"A\",\"name\":\"$dnshost\",\"content\":\"$ipv4\",\"ttl\":1,\"proxied\":false,\"comment\":\"$tag\"}"
    if [[ "$dnsrecordid" == "null" ]]; then
	# create the record
	echo "IPv4: Creating A record ($ipv4)"
	curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$zoneid/dns_records" \
	     -H "X-Auth-Email: $cloudflare_auth_email" \
	     -H "Authorization: Bearer $cloudflare_auth_key" \
	     -H "Content-Type: application/json" \
	     --data $body | jq
    else
	# update the record
	echo "IPv4: Updating A record ($dnsv4 -> $ipv4)"
	curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$zoneid/dns_records/$dnsrecordid" \
	     -H "X-Auth-Email: $cloudflare_auth_email" \
	     -H "Authorization: Bearer $cloudflare_auth_key" \
	     -H "Content-Type: application/json" \
	     --data $body | jq
    fi
fi

# IPv6 : get AAAA record
dnsrecord=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$zoneid/dns_records?type=AAAA&name=$dnshost&comment=$tag" \
		 -H "X-Auth-Email: $cloudflare_auth_email" \
		 -H "Authorization: Bearer $cloudflare_auth_key" \
		 -H "Content-Type: application/json" | jq -r '{"result"}[] | .[0]')

dnsrecordid=$(echo $dnsrecord | jq -r .id)
dnsv6=$(echo $dnsrecord | jq -r .content)

if [[ "$ipv6" == "" ]]; then
    echo "This host does not have public IPv6 address"
elif [[ "$ipv6" == "$dnsv6" ]]; then
    echo "IPv6: $dnshost is currently set to $ipv6; no changes needed"
else
    body="{\"type\":\"AAAA\",\"name\":\"$dnshost\",\"content\":\"$ipv6\",\"ttl\":1,\"proxied\":false,\"comment\":\"$tag\"}"
    if [[ "$dnsrecordid" == "null" ]]; then
	# create the record
	echo "IPv6: Creating AAAA record ($ipv6)"
	curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$zoneid/dns_records" \
	     -H "X-Auth-Email: $cloudflare_auth_email" \
	     -H "Authorization: Bearer $cloudflare_auth_key" \
	     -H "Content-Type: application/json" \
	     --data $body | jq
    else
	# update the record
	echo "IPv6: Updating AAAA record ($dnsv6 -> $ipv6)"
	curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$zoneid/dns_records/$dnsrecordid" \
	     -H "X-Auth-Email: $cloudflare_auth_email" \
	     -H "Authorization: Bearer $cloudflare_auth_key" \
	     -H "Content-Type: application/json" \
	     --data $body | jq
    fi

fi
