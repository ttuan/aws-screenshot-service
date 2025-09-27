#!/bin/bash

# Test script to send multiple screenshot requests to the API
# This will help test SQS-based auto scaling

# Default environment (can be overridden with -e flag)
ENVIRONMENT="prd"
TOTAL_REQUESTS=20

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  -e, --env ENVIRONMENT    Environment to test (prd or stg). Default: prd"
    echo "  -r, --requests NUMBER    Number of requests to send. Default: 150"
    echo "  -h, --help              Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                      # Test production with 150 requests"
    echo "  $0 -e stg -r 50         # Test staging with 50 requests"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -e|--env)
            ENVIRONMENT="$2"
            shift 2
            ;;
        -r|--requests)
            TOTAL_REQUESTS="$2"
            shift 2
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Validate environment
if [[ "$ENVIRONMENT" != "prd" && "$ENVIRONMENT" != "stg" ]]; then
    echo "Error: Environment must be 'prd' or 'stg'"
    exit 1
fi

# Get the API endpoint dynamically from Terraform outputs
echo "🔍 Retrieving API Gateway endpoint for environment: $ENVIRONMENT"
TERRAFORM_DIR="$(dirname "$0")/../terraform/envs/$ENVIRONMENT/4.deployment"

if [[ ! -d "$TERRAFORM_DIR" ]]; then
    echo "❌ Error: Terraform directory not found: $TERRAFORM_DIR"
    echo "Make sure you're running this script from the correct location."
    exit 1
fi

# Change to terraform directory and get the output
cd "$TERRAFORM_DIR" || exit 1

API_ENDPOINT=$(terraform output -raw screenshot_endpoint 2>/dev/null)
if [[ $? -ne 0 || -z "$API_ENDPOINT" ]]; then
    echo "❌ Error: Failed to retrieve screenshot_endpoint from Terraform outputs"
    echo "Make sure Terraform has been applied and the infrastructure is deployed."
    echo "Try running: cd $TERRAFORM_DIR && terraform output screenshot_endpoint"
    exit 1
fi

# Return to original directory
cd - > /dev/null

# Validate the API endpoint format
if [[ ! "$API_ENDPOINT" =~ ^https://[a-z0-9]+\.execute-api\.[a-z0-9-]+\.amazonaws\.com/[a-z]+/api/screenshot$ ]]; then
    echo "❌ Error: Retrieved API endpoint doesn't match expected format"
    echo "Retrieved: $API_ENDPOINT"
    echo "Expected format: https://{api-id}.execute-api.{region}.amazonaws.com/{stage}/api/screenshot"
    exit 1
fi

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

echo ""
echo "✅ Successfully retrieved API endpoint: $API_ENDPOINT"
echo ""
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
