#!/bin/bash

# Test script to send multiple screenshot requests to the API
# This will help test SQS-based auto scaling

API_ENDPOINT="https://vbs2top645.execute-api.us-east-1.amazonaws.com/prod/api/screenshot"
TOTAL_REQUESTS=150

# Arrays of realistic test data
urls=(
    "https://google.com"
    "https://github.com"
    "https://stackoverflow.com"
    "https://aws.amazon.com"
    "https://reddit.com"
    "https://twitter.com"
    "https://linkedin.com"
    "https://medium.com"
    "https://dev.to"
    "https://news.ycombinator.com"
    "https://docker.com"
    "https://kubernetes.io"
    "https://terraform.io"
    "https://netflix.com"
)

# Common viewport dimensions
widths=(1920 1366 1280 1024 768 1440 1600 375 414 360)
heights=(1080 768 720 768 1024 900 900 667 896 640)

echo "Starting screenshot request test..."
echo "Sending $TOTAL_REQUESTS requests to: $API_ENDPOINT"
echo "================================================="

# Function to send a single request
send_request() {
    local request_num=$1
    local url=${urls[$((RANDOM % ${#urls[@]}))]}
    local width=${widths[$((RANDOM % ${#widths[@]}))]}
    local height=${heights[$((RANDOM % ${#heights[@]}))]}

    echo "[$request_num/$TOTAL_REQUESTS] Requesting screenshot of: $url (${width}x${height})"

    response=$(curl -s -w "\nHTTP_STATUS:%{http_code}\nTIME_TOTAL:%{time_total}" \
        -X POST "$API_ENDPOINT" \
        -H "Content-Type: application/json" \
        -d "{
            \"url\": \"$url\",
            \"options\": {
                \"width\": $width,
                \"height\": $height
            }
        }")

    # Parse response
    http_status=$(echo "$response" | grep "HTTP_STATUS:" | cut -d: -f2)
    time_total=$(echo "$response" | grep "TIME_TOTAL:" | cut -d: -f2)
    body=$(echo "$response" | sed '/HTTP_STATUS:/,$d')

    if [ "$http_status" = "200" ] || [ "$http_status" = "202" ]; then
        echo "  ✅ Success (HTTP $http_status) - Time: ${time_total}s"
        if [ -n "$body" ]; then
            echo "  📝 Response: $body"
        fi
    else
        echo "  ❌ Failed (HTTP $http_status) - Time: ${time_total}s"
        if [ -n "$body" ]; then
            echo "  📝 Error: $body"
        fi
    fi
    echo ""
}

# Send requests with small delays to simulate real usage
for i in $(seq 1 $TOTAL_REQUESTS); do
    send_request $i

    # Add random delay between 1-3 seconds to simulate realistic request patterns
    sleep_time=$((RANDOM % 5 + 1))
    if [ $i -lt $TOTAL_REQUESTS ]; then
        echo "⏳ Waiting ${sleep_time}s before next request..."
        sleep $sleep_time
    fi
done

echo "================================================="
echo "✅ Test completed! Sent $TOTAL_REQUESTS screenshot requests."
echo ""
echo "🔍 Check your AWS Console to monitor:"
echo "  - SQS Queue depth in CloudWatch"
echo "  - ECS Service scaling activity"
echo "  - CloudWatch alarms status"
echo ""
echo "📊 Expected behavior:"
echo "  - SQS messages should accumulate quickly"
echo "  - ECS tasks should scale up when queue depth > 5"
echo "  - Tasks should scale down after processing completes"
