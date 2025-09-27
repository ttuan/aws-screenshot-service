#!/bin/bash

# AWS Resource Cleanup Script
# This script removes all resources created by pre-build.sh and Terraform infrastructure
# ⚠️  WARNING: This will permanently delete AWS resources and data!

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  -p, --project PROJECT    Project name (e.g., screenshot-service)"
    echo "  -e, --env ENV           Environment (prd, stg, dev)"
    echo "  -r, --region REGION     AWS region (e.g., us-east-1)"
    echo "  --dry-run              Show what would be deleted without actually deleting"
    echo "  --force                Skip confirmation prompts"
    echo "  -h, --help             Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 -p screenshot-service -e prd -r us-east-1"
    echo "  $0 -p screenshot-service -e prd -r us-east-1 --dry-run"
    echo "  $0 -p screenshot-service -e prd -r us-east-1 --force"
}

# Default values
DRY_RUN=false
FORCE=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -p|--project)
            PROJECT="$2"
            shift 2
            ;;
        -e|--env)
            ENV="$2"
            shift 2
            ;;
        -r|--region)
            REGION="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --force)
            FORCE=true
            shift
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            echo "Unknown option $1"
            show_usage
            exit 1
            ;;
    esac
done

# Validate required parameters
if [[ -z "$PROJECT" || -z "$ENV" || -z "$REGION" ]]; then
    print_error "Missing required parameters!"
    show_usage
    exit 1
fi

# Set AWS profile
AWS_PROFILE="${PROJECT}-${ENV}"

# Resource names based on pre-build.sh naming convention
S3_STATE_BUCKET="${PROJECT}-${ENV}-iac-state"
DYNAMODB_TABLE="${PROJECT}-${ENV}-terraform-state-lock"
KMS_ALIAS="alias/${PROJECT}-${ENV}-iac"
S3_SCREENSHOTS_BUCKET="${PROJECT}-${ENV}"

print_info "AWS Resource Cleanup Configuration:"
echo "  Project: $PROJECT"
echo "  Environment: $ENV"
echo "  Region: $REGION"
echo "  AWS Profile: $AWS_PROFILE"
echo "  Dry Run: $DRY_RUN"
echo ""

# Function to execute or simulate AWS commands
execute_aws_command() {
    local description="$1"
    local command="$2"

    if [[ "$DRY_RUN" == "true" ]]; then
        print_info "[DRY RUN] $description"
        echo "  Command: $command"
    else
        print_info "$description"
        if eval "$command"; then
            print_success "Completed: $description"
        else
            print_warning "Failed or not found: $description"
        fi
    fi
}

# Confirmation prompt
if [[ "$FORCE" != "true" && "$DRY_RUN" != "true" ]]; then
    print_warning "This will permanently delete the following AWS resources:"
    echo "  - S3 Bucket: $S3_STATE_BUCKET (with all objects and versions)"
    echo "  - S3 Bucket: $S3_SCREENSHOTS_BUCKET (with all objects and versions)"
    echo "  - DynamoDB Table: $DYNAMODB_TABLE"
    echo "  - KMS Key and Alias: $KMS_ALIAS"
    echo ""
    print_info "Resources that will be PRESERVED:"
    echo "  - ECR Repository: $ECR_REPO_NAME (backend container images)"
    echo ""
    read -p "Are you absolutely sure you want to continue? (type 'yes' to confirm): " confirmation

    if [[ "$confirmation" != "yes" ]]; then
        print_info "Operation cancelled by user"
        exit 0
    fi
fi

echo ""
print_info "Starting AWS resource cleanup..."

# Function to empty and delete S3 bucket with versioning
cleanup_s3_bucket() {
    local bucket_name="$1"
    local description="$2"

    print_info "$description: $bucket_name"

    if [[ "$DRY_RUN" == "true" ]]; then
        print_info "[DRY RUN] Would empty and delete S3 bucket: $bucket_name"
        return
    fi

    # Check if bucket exists
    if ! aws s3api head-bucket --bucket "$bucket_name" --profile "$AWS_PROFILE" --region "$REGION" 2>/dev/null; then
        print_warning "Bucket $bucket_name does not exist or is not accessible"
        return
    fi

    print_info "Emptying bucket $bucket_name (removing all objects and versions)..."

    # Delete all object versions
    aws s3api list-object-versions \
        --bucket "$bucket_name" \
        --profile "$AWS_PROFILE" \
        --region "$REGION" \
        --output json 2>/dev/null | \
    jq -r '.Versions[]? | "\(.Key)\t\(.VersionId)"' | \
    while IFS=$'\t' read -r key version; do
        if [[ -n "$key" && -n "$version" ]]; then
            aws s3api delete-object \
                --bucket "$bucket_name" \
                --key "$key" \
                --version-id "$version" \
                --profile "$AWS_PROFILE" \
                --region "$REGION" >/dev/null 2>&1
        fi
    done

    # Delete all delete markers
    aws s3api list-object-versions \
        --bucket "$bucket_name" \
        --profile "$AWS_PROFILE" \
        --region "$REGION" \
        --output json 2>/dev/null | \
    jq -r '.DeleteMarkers[]? | "\(.Key)\t\(.VersionId)"' | \
    while IFS=$'\t' read -r key version; do
        if [[ -n "$key" && -n "$version" ]]; then
            aws s3api delete-object \
                --bucket "$bucket_name" \
                --key "$key" \
                --version-id "$version" \
                --profile "$AWS_PROFILE" \
                --region "$REGION" >/dev/null 2>&1
        fi
    done

    # Delete the bucket
    if aws s3api delete-bucket \
        --bucket "$bucket_name" \
        --profile "$AWS_PROFILE" \
        --region "$REGION" 2>/dev/null; then
        print_success "Deleted S3 bucket: $bucket_name"
    else
        print_error "Failed to delete S3 bucket: $bucket_name"
    fi
}

# 1. Clean up S3 buckets
print_info "=== S3 Bucket Cleanup ==="
cleanup_s3_bucket "$S3_STATE_BUCKET" "Terraform state bucket"
cleanup_s3_bucket "$S3_SCREENSHOTS_BUCKET" "Screenshots storage bucket"

# 2. Delete DynamoDB table
print_info "=== DynamoDB Table Cleanup ==="
execute_aws_command \
    "Deleting DynamoDB table: $DYNAMODB_TABLE" \
    "aws dynamodb delete-table --table-name '$DYNAMODB_TABLE' --profile '$AWS_PROFILE' --region '$REGION'"

# 3. Delete KMS key and alias
print_info "=== KMS Key Cleanup ==="

# Get KMS key ID from alias
if [[ "$DRY_RUN" == "true" ]]; then
    print_info "[DRY RUN] Would delete KMS alias: $KMS_ALIAS"
    print_info "[DRY RUN] Would schedule KMS key deletion"
else
    # Get key ID from alias
    KMS_KEY_ID=$(aws kms describe-key \
        --key-id "$KMS_ALIAS" \
        --query "KeyMetadata.KeyId" \
        --output text \
        --profile "$AWS_PROFILE" \
        --region "$REGION" 2>/dev/null || echo "")

    if [[ -n "$KMS_KEY_ID" && "$KMS_KEY_ID" != "None" ]]; then
        # Delete alias first
        execute_aws_command \
            "Deleting KMS alias: $KMS_ALIAS" \
            "aws kms delete-alias --alias-name '$KMS_ALIAS' --profile '$AWS_PROFILE' --region '$REGION'"

        # Schedule key deletion (7 day waiting period)
        execute_aws_command \
            "Scheduling KMS key deletion (7 days): $KMS_KEY_ID" \
            "aws kms schedule-key-deletion --key-id '$KMS_KEY_ID' --pending-window-in-days 7 --profile '$AWS_PROFILE' --region '$REGION'"
    else
        print_warning "KMS key not found or already deleted: $KMS_ALIAS"
    fi
fi

# 4. ECR Repository - SKIPPED (preserved for backend images)
print_info "=== ECR Repository ==="
ECR_REPO_NAME="${PROJECT}-${ENV}"
print_info "🔒 Preserving ECR repository: $ECR_REPO_NAME (contains backend images)"

# Summary
echo ""
print_info "=== Cleanup Summary ==="
if [[ "$DRY_RUN" == "true" ]]; then
    print_info "DRY RUN completed. No resources were actually deleted."
    print_info "Run without --dry-run to perform actual deletion."
else
    print_success "AWS resource cleanup completed!"
    print_warning "Note: KMS keys are scheduled for deletion (7-day waiting period)"
    print_info "All other resources have been permanently deleted."
fi

echo ""
print_info "Resources that were processed:"
echo "  ✓ S3 Bucket (Terraform state): $S3_STATE_BUCKET"
echo "  ✓ S3 Bucket (Screenshots): $S3_SCREENSHOTS_BUCKET"
echo "  ✓ DynamoDB Table: $DYNAMODB_TABLE"
echo "  ✓ KMS Key and Alias: $KMS_ALIAS"
echo "  🔒 ECR Repository (preserved): $ECR_REPO_NAME"

if [[ "$DRY_RUN" != "true" ]]; then
    echo ""
    print_warning "⚠️  Remember to:"
    echo "  1. Remove AWS credentials/profiles if no longer needed"
    echo "  2. Check AWS console to verify all resources are deleted"
    echo "  3. Monitor any remaining charges in AWS billing"
fi