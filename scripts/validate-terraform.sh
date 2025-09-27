#!/bin/bash

# Script to validate all Terraform configurations
# This mimics the CI workflow validation process

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default environment
ENVIRONMENT="prd"

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  -e, --env ENVIRONMENT    Environment to validate (prd or stg). Default: prd"
    echo "  -h, --help              Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                      # Validate production environment"
    echo "  $0 -e stg               # Validate staging environment (may fail with private modules)"
    echo ""
    echo "Note: Staging environment may fail validation due to private module dependencies."
    echo "      The CI workflow only validates the production environment."
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -e|--env)
            ENVIRONMENT="$2"
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
    echo -e "${RED}Error: Environment must be 'prd' or 'stg'${NC}"
    exit 1
fi

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo -e "${BLUE}🔍 Validating Terraform configurations for environment: ${ENVIRONMENT}${NC}"
echo "================================================="

# Check if environment directory exists
ENV_DIR="$PROJECT_ROOT/terraform/envs/$ENVIRONMENT"
if [[ ! -d "$ENV_DIR" ]]; then
    echo -e "${RED}❌ Error: Environment directory not found: $ENV_DIR${NC}"
    exit 1
fi

# First, check Terraform formatting
echo -e "${YELLOW}📝 Checking Terraform formatting...${NC}"
if terraform fmt -check -recursive "$PROJECT_ROOT/terraform/" >/dev/null 2>&1; then
    echo -e "${GREEN}✅ Terraform formatting is correct${NC}"
else
    echo -e "${RED}❌ Terraform formatting issues found${NC}"
    echo "Run 'terraform fmt -recursive terraform/' to fix formatting"
    exit 1
fi

# Validate each service
echo -e "${YELLOW}🔍 Validating Terraform configurations...${NC}"

TOTAL_SERVICES=0
VALID_SERVICES=0
FAILED_SERVICES=()

for service in $(ls "$ENV_DIR" | grep -E '^[0-9]' | sort); do
    SERVICE_DIR="$ENV_DIR/$service"

    if [[ ! -d "$SERVICE_DIR" ]]; then
        continue
    fi

    TOTAL_SERVICES=$((TOTAL_SERVICES + 1))
    echo -n "  🔧 Validating service: $service ... "

    # Change to service directory
    cd "$SERVICE_DIR" || {
        echo -e "${RED}Failed to change directory${NC}"
        FAILED_SERVICES+=("$service (directory access)")
        continue
    }

    # Initialize Terraform (without backend)
    INIT_OUTPUT=$(terraform init -backend=false 2>&1)
    if [[ $? -ne 0 ]]; then
        # Check if it's a module download issue (common in staging with private repos)
        if echo "$INIT_OUTPUT" | grep -q "Repository not found\|Could not download module"; then
            echo -e "${YELLOW}⚠️  Module access issue (likely private repo)${NC}"
            FAILED_SERVICES+=("$service (private module access)")
        else
            echo -e "${RED}❌ Init failed${NC}"
            FAILED_SERVICES+=("$service (init)")
            echo -e "${RED}    Error details:${NC}"
            echo "$INIT_OUTPUT" | sed 's/^/      /'
        fi
        cd "$PROJECT_ROOT" || exit 1
        continue
    fi

    # Validate configuration
    if terraform validate >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Valid${NC}"
        VALID_SERVICES=$((VALID_SERVICES + 1))
    else
        echo -e "${RED}❌ Invalid${NC}"
        FAILED_SERVICES+=("$service (validation)")
        # Show detailed error for debugging
        echo -e "${RED}    Error details:${NC}"
        terraform validate 2>&1 | sed 's/^/      /'
    fi

    # Return to project root
    cd "$PROJECT_ROOT" || exit 1
done

echo "================================================="

# Summary
if [[ ${#FAILED_SERVICES[@]} -eq 0 ]]; then
    echo -e "${GREEN}🎉 All validations passed!${NC}"
    echo -e "${GREEN}✅ $VALID_SERVICES/$TOTAL_SERVICES services validated successfully${NC}"
    exit 0
else
    echo -e "${RED}❌ Some validations failed:${NC}"
    for failed in "${FAILED_SERVICES[@]}"; do
        echo -e "${RED}  - $failed${NC}"
    done
    echo -e "${YELLOW}✅ $VALID_SERVICES/$TOTAL_SERVICES services validated successfully${NC}"
    exit 1
fi
