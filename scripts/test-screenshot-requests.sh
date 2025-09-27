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

# Arrays to track all responses for summary
declare -a summary_urls=()
declare -a summary_dimensions=()
declare -a summary_status_codes=()
declare -a summary_success=()
declare -a summary_job_ids=()
declare -a summary_status_urls=()
declare -a summary_messages=()
declare -a summary_response_times=()
declare -a summary_screenshot_urls=()

echo ""
echo "✅ Successfully retrieved API endpoint: $API_ENDPOINT"
echo ""
echo "Starting screenshot request test..."
echo "Sending $TOTAL_REQUESTS requests to: $API_ENDPOINT"
echo "================================================="

# Function to parse JSON and extract a field
parse_json_field() {
    local json="$1"
    local field="$2"
    echo "$json" | sed -n 's/.*"'"$field"'":"\([^"]*\)".*/\1/p'
}

# Function to check status URL and get screenshot URL
check_status_and_get_screenshot() {
    local status_url="$1"
    local max_attempts=15  # Increased for longer processing time
    local attempt=1

    # Progressive wait times: start with 10s, then increase
    local wait_times=(10 10 15 15 20 20 20 30 30 30 30 45 45 60 60)

    echo "    ⏳ Waiting 10s before first status check (allowing processing time)..." >&2
    sleep 10

    while [ $attempt -le $max_attempts ]; do
        local wait_time=${wait_times[$((attempt-1))]}
        echo "    Checking status (attempt $attempt/$max_attempts)..." >&2

        status_response=$(curl -s -w "\nHTTP_STATUS:%{http_code}" -X GET "$status_url")
        status_http_code=$(echo "$status_response" | grep "HTTP_STATUS:" | cut -d: -f2)
        status_body=$(echo "$status_response" | sed '/HTTP_STATUS:/,$d')

        if [ "$status_http_code" = "200" ]; then
            # Parse the status response
            job_status=$(parse_json_field "$status_body" "status")

            if [ "$job_status" = "completed" ]; then
                screenshot_url=$(parse_json_field "$status_body" "publicUrl")
                if [ -n "$screenshot_url" ]; then
                    echo "    ✅ Screenshot ready after $((attempt * 10 + 10))s: $screenshot_url" >&2
                    echo "$screenshot_url"
                    return 0
                else
                    echo "    ⚠️  Job completed but no publicUrl found" >&2
                    echo "N/A"
                    return 1
                fi
            elif [ "$job_status" = "failed" ] || [ "$job_status" = "error" ]; then
                echo "    ❌ Job failed with status: $job_status" >&2
                echo "FAILED"
                return 1
            elif [ "$job_status" = "pending" ] || [ "$job_status" = "processing" ] || [ "$job_status" = "uploading" ]; then
                echo "    ⏳ Job status: $job_status (waiting ${wait_time}s for screenshot processing and S3 upload...)" >&2
                sleep $wait_time
            else
                echo "    ❓ Unknown job status: $job_status (waiting ${wait_time}s...)" >&2
                sleep $wait_time
            fi
        else
            echo "    ⚠️  Status check failed (HTTP $status_http_code), retrying in ${wait_time}s..." >&2
            sleep $wait_time
        fi

        ((attempt++))
    done

    echo "    ⚠️  Timeout after $(( max_attempts * 30 ))s - screenshot may still be processing" >&2
    echo "TIMEOUT"
    return 1
}

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

    # Store data for summary
    summary_urls+=("$url")
    summary_dimensions+=("${width}x${height}")
    summary_status_codes+=("$http_status")
    summary_response_times+=("$time_total")

    if [ "$http_status" = "200" ] || [ "$http_status" = "202" ]; then
        echo "  ✅ Success (HTTP $http_status) - Time: ${time_total}s"
        summary_success+=("true")

        if [ -n "$body" ]; then
            echo "  📝 Response: $body"

            # Extract job ID and status URL from JSON response
            job_id=$(parse_json_field "$body" "jobId")
            status_url=$(parse_json_field "$body" "statusUrl")
            message=$(parse_json_field "$body" "message")

            # Store extracted data
            summary_job_ids+=("$job_id")
            summary_messages+=("$message")

            # Build full status URL by combining API endpoint base with status URL
            if [ -n "$status_url" ]; then
                # Extract base URL from API_ENDPOINT (remove /api/screenshot)
                base_url=$(echo "$API_ENDPOINT" | sed 's|/api/screenshot$||')
                full_status_url="${base_url}${status_url}"
                summary_status_urls+=("$full_status_url")
            else
                summary_status_urls+=("N/A")
            fi
        else
            summary_job_ids+=("N/A")
            summary_messages+=("N/A")
            summary_status_urls+=("N/A")
        fi
    else
        echo "  ❌ Failed (HTTP $http_status) - Time: ${time_total}s"
        summary_success+=("false")
        summary_job_ids+=("N/A")
        summary_status_urls+=("N/A")

        if [ -n "$body" ]; then
            echo "  📝 Error: $body"
            summary_messages+=("$body")
        else
            summary_messages+=("HTTP Error $http_status")
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

# Check status URLs and get screenshot URLs for successful requests
echo "🔍 Checking status of successful requests to get screenshot URLs..."
echo "================================================="

for i in "${!summary_success[@]}"; do
    if [ "${summary_success[i]}" = "true" ] && [ "${summary_status_urls[i]}" != "N/A" ]; then
        echo "Checking request $((i+1)) (${summary_urls[i]}):"

        # Call function and show progress while capturing result
        screenshot_url=$(check_status_and_get_screenshot "${summary_status_urls[i]}")

        summary_screenshot_urls+=("$screenshot_url")
        echo ""
    else
        summary_screenshot_urls+=("N/A")
    fi
done

echo "================================================="

# Display summary of all requests
echo "📊 REQUEST SUMMARY"
echo "================================================="

# Count successes and failures
success_count=0
failure_count=0
for status in "${summary_success[@]}"; do
    if [ "$status" = "true" ]; then
        ((success_count++))
    else
        ((failure_count++))
    fi
done

echo "📈 Overall Statistics:"
echo "  ✅ Successful requests: $success_count"
echo "  ❌ Failed requests: $failure_count"
echo "  📊 Success rate: $(( success_count * 100 / TOTAL_REQUESTS ))%"

# Calculate average response time
total_time=0
count=0
for time in "${summary_response_times[@]}"; do
    if [[ "$time" =~ ^[0-9]+\.?[0-9]*$ ]]; then
        total_time=$(echo "$total_time + $time" | bc -l 2>/dev/null || echo "$total_time")
        ((count++))
    fi
done

if [ $count -gt 0 ]; then
    avg_time=$(echo "scale=3; $total_time / $count" | bc -l 2>/dev/null || echo "N/A")
    echo "  ⏱️  Average response time: ${avg_time}s"
fi

echo ""
echo "📋 Detailed Results:"
echo "================================================="

# Display detailed summary table
printf "%-4s %-30s %-12s %-6s %-8s %-36s %-20s\n" "No." "URL" "Dimensions" "Status" "Time(s)" "Job ID" "Screenshot Status"
echo "--------------------------------------------------------------------------------------------------------------"

for i in "${!summary_urls[@]}"; do
    url="${summary_urls[i]}"
    dimensions="${summary_dimensions[i]}"
    status_code="${summary_status_codes[i]}"
    time="${summary_response_times[i]}"
    job_id="${summary_job_ids[i]}"
    screenshot_url="${summary_screenshot_urls[i]}"

    # Truncate long URLs for display
    if [ ${#url} -gt 28 ]; then
        display_url="${url:0:25}..."
    else
        display_url="$url"
    fi

    # Truncate long job IDs for display
    if [ ${#job_id} -gt 34 ]; then
        display_job_id="${job_id:0:31}..."
    else
        display_job_id="$job_id"
    fi

    # Determine screenshot status for display
    if [ "$screenshot_url" = "N/A" ]; then
        screenshot_status="N/A"
    elif [ "$screenshot_url" = "FAILED" ]; then
        screenshot_status="❌ Failed"
    elif [ "$screenshot_url" = "TIMEOUT" ]; then
        screenshot_status="⏰ Timeout"
    elif [[ "$screenshot_url" =~ ^https:// ]]; then
        screenshot_status="✅ Ready"
    else
        screenshot_status="❓ Unknown"
    fi

    printf "%-4s %-30s %-12s %-6s %-8s %-36s %-20s\n" \
        "$((i+1))" "$display_url" "$dimensions" "$status_code" "$time" "$display_job_id" "$screenshot_status"
done

echo ""
echo "📸 Screenshot URLs for completed requests:"
echo "================================================="

completed_count=0
for i in "${!summary_success[@]}"; do
    if [ "${summary_success[i]}" = "true" ] && [ "${summary_status_urls[i]}" != "N/A" ]; then
        job_id="${summary_job_ids[i]}"
        status_url="${summary_status_urls[i]}"
        screenshot_url="${summary_screenshot_urls[i]}"
        url="${summary_urls[i]}"

        echo "Request $((i+1)) ($url):"
        echo "  Job ID: $job_id"
        echo "  Status URL: $status_url"

        if [[ "$screenshot_url" =~ ^https:// ]]; then
            echo "  📸 Screenshot URL: $screenshot_url"
            ((completed_count++))
        elif [ "$screenshot_url" = "FAILED" ]; then
            echo "  ❌ Screenshot generation failed"
        elif [ "$screenshot_url" = "TIMEOUT" ]; then
            echo "  ⏰ Screenshot generation timed out"
        else
            echo "  ⚠️  Screenshot not available"
        fi
        echo ""
    fi
done

if [ $completed_count -gt 0 ]; then
    echo "🎉 Successfully generated $completed_count screenshot(s)!"
else
    echo "⚠️  No screenshots were successfully generated."
fi
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
