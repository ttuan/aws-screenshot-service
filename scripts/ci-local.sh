#!/bin/bash

# Local CI Script - Chạy validation như trên GitHub Actions
# Usage: ./scripts/ci-local.sh

set -euo pipefail

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Check if we're in the right directory
if [ ! -f "Makefile" ] || [ ! -d "terraform" ]; then
    print_error "Chạy script này từ thư mục gốc của project"
    exit 1
fi

print_status "🚀 Bắt đầu chạy CI validation locally..."

# Step 1: Terraform validation
print_status "🏗️  Validating Terraform configurations..."
TERRAFORM_FAILED=false

# Check formatting
if terraform fmt -check -recursive terraform/; then
    print_success "Terraform formatting is correct"
else
    print_error "Terraform formatting issues found"
    print_warning "Run: terraform fmt -recursive terraform/"
    TERRAFORM_FAILED=true
fi

# Validate configurations
for env in prd; do
    if [ -d "terraform/envs/$env" ]; then
        print_status "Validating $env environment..."

        for service_dir in terraform/envs/$env/*/; do
            if [[ $(basename "$service_dir") =~ ^[0-9] ]]; then
                service=$(basename "$service_dir")
                print_status "  Validating $service..."

                cd "$service_dir"

                if terraform init -backend=false > /dev/null 2>&1; then
                    if terraform validate > /dev/null 2>&1; then
                        print_success "  $service validation passed"
                    else
                        print_error "  $service validation failed"
                        TERRAFORM_FAILED=true
                    fi
                else
                    print_error "  $service terraform init failed"
                    TERRAFORM_FAILED=true
                fi

                cd - > /dev/null
            fi
        done
    fi
done

# Step 2: Basic security check
print_status "🔒 Running basic security checks..."
SECURITY_FAILED=false

# Check for AWS keys
if grep -r "AKIA[0-9A-Z]\{16\}" . --exclude-dir=.git --exclude-dir=node_modules 2>/dev/null; then
    print_error "AWS Access Key found in code!"
    SECURITY_FAILED=true
fi

# Check for potential passwords
if grep -r "password.*=" . --include="*.tf" --include="*.js" --exclude-dir=.git --exclude-dir=node_modules 2>/dev/null; then
    print_warning "Potential password found in code"
    print_warning "Please review and ensure no sensitive data is committed"
fi

if [ "$SECURITY_FAILED" = false ]; then
    print_success "Basic security checks passed"
fi

# Summary
echo ""
echo "=========================================="
echo "           CI VALIDATION SUMMARY"
echo "=========================================="

if [ "$TERRAFORM_FAILED" = true ] || [ "$SECURITY_FAILED" = true ]; then
    print_error "❌ CI validation failed!"
    echo ""
    if [ "$TERRAFORM_FAILED" = true ]; then
        echo "- Terraform validation failed"
    fi
    if [ "$SECURITY_FAILED" = true ]; then
        echo "- Security checks failed"
    fi
    echo ""
    exit 1
else
    print_success "✅ All CI validations passed!"
    echo ""
    echo "Your code is ready for commit and push!"
    echo ""
fi
