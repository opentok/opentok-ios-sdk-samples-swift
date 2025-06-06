#!/bin/bash

PAYLOAD=""

if [ -z "$1" ]
  then
    PAYLOAD="{\"aps\":{\"content-available\" : 1}, \"UUID\":\"d030f126-f523-476a-89cf-08fd0d806fe0\", \"handle\":\"Ford Prefect\"}"
  else 
    PAYLOAD=$(<$1)
fi

TEAMID=""
KEYID="p8 key name here"
SECRET="p8 file path"
BUNDLEID="com.vonage.CallKitDemo.voip"
DEVICETOKEN="your device voip token"

function base64URLSafe {
  openssl base64 -e -A | tr -- '+/' '-_' | tr -d =
}

function sign {
  printf "$1"| openssl dgst -binary -sha256 -sign "$SECRET" | base64URLSafe
}

time=$(date +%s)
header=$(printf '{ "alg": "ES256", "kid": "%s" }' "$KEYID" | base64URLSafe)
claims=$(printf '{ "iss": "%s", "iat": %d }' "$TEAMID" "$time" | base64URLSafe)
jwt="$header.$claims.$(sign $header.$claims)"

# Development server: api.sandbox.push.apple.com:443
ENDPOINT=https://api.sandbox.push.apple.com:443
# 
# Production server: api.push.apple.com:443
# Uncomment URL below to send pushes to production server
# ENDPOINT=https://api.push.apple.com:443
# 
URLPATH=/3/device/

URL=$ENDPOINT$URLPATH$DEVICETOKEN

curl -v \
   --http2 \
   --header "authorization: bearer $jwt" \
   --header "apns-topic: ${BUNDLEID}" \
   --header "apns-push-type: voip" \
   --header "apns-priority: 10" \
   --data "${PAYLOAD}" \
   "${URL}"
