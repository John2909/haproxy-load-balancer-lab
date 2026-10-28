#!/bin/bash
# Sends ~5 requests/second for 30 seconds and logs time + HTTP status code
end=$((SECONDS+30))
while [ $SECONDS -lt $end ]; do
  echo "$(date +%T.%3N) $(curl -s -o /dev/null -w '%{http_code}' --max-time 2 http://192.168.11.100)"
  sleep 0.2
done