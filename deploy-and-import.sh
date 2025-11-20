#!/bin/bash

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_VCD_DIR="${SCRIPT_DIR}/terraform-vCD"
TERRAFORM_IMPORT_DIR="${SCRIPT_DIR}/terraform-import-resources"

# Function to print colored messages
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Generate date string for plan file (format: YYYY-MM-DD)
PLAN_DATE=$(date +%Y-%m-%d)
PLAN_FILE="plan-${PLAN_DATE}.tfplan"

# Function to validate IP address format
validate_ip() {
    local ip=$1
    if [[ $ip =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        IFS='.' read -ra ADDR <<< "$ip"
        for i in "${ADDR[@]}"; do
            if [[ $i -gt 255 ]]; then
                return 1
            fi
        done
        return 0
    fi
    return 1
}

# Function to validate CIDR format
validate_cidr() {
    local cidr=$1
    if [[ $cidr =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}/[0-9]{1,2}$ ]]; then
        local ip=$(echo "$cidr" | cut -d'/' -f1)
        local prefix=$(echo "$cidr" | cut -d'/' -f2)
        if validate_ip "$ip" && [[ $prefix -ge 0 && $prefix -le 32 ]]; then
            return 0
        fi
    fi
    return 1
}

# Function to validate VLAN ID (105-150)
validate_vlan_id() {
    local vlan_id=$1
    if [[ $vlan_id =~ ^[0-9]+$ ]] && [[ $vlan_id -ge 105 && $vlan_id -le 150 ]]; then
        return 0
    fi
    return 1
}

# Function to prompt for input with validation
prompt_input() {
    local prompt_text=$1
    local var_name=$2
    local validation_func=$3
    local value=""
    
    while true; do
        echo -ne "${YELLOW}[INPUT]${NC} ${prompt_text}: "
        read -r value
        if [ -z "$value" ]; then
            print_error "This field is required. Please enter a value."
            continue
        fi
        if [ -n "$validation_func" ]; then
            if $validation_func "$value"; then
                eval "$var_name='$value'"
                break
            else
                print_error "Invalid format. Please try again."
            fi
        else
            eval "$var_name='$value'"
            break
        fi
    done
}

# Function to update terraform.tfvars using sed
update_tfvars() {
    local file_path="${TERRAFORM_VCD_DIR}/terraform.tfvars"
    local key=$1
    local value=$2
    
    # Check if file exists
    if [ ! -f "$file_path" ]; then
        print_error "terraform.tfvars file not found at ${file_path}"
        exit 1
    fi
    
    # Escape special characters in value for sed replacement
    # Escape backslashes first, then other special characters
    local escaped_value=$(printf '%s\n' "$value" | sed 's/\\/\\\\/g' | sed 's/&/\\&/g' | sed 's/|/\\|/g')
    
    # Pattern to match: key = "" or key  = "" (handles variable spacing)
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS uses BSD sed
        sed -i '' "s|^${key}[[:space:]]*=[[:space:]]*\".*\"|${key} = \"${escaped_value}\"|" "$file_path"
    else
        # Linux uses GNU sed
        sed -i "s|^${key}[[:space:]]*=[[:space:]]*\".*\"|${key} = \"${escaped_value}\"|" "$file_path"
    fi
    
    if [ $? -ne 0 ]; then
        print_error "Failed to update ${key} in terraform.tfvars"
        exit 1
    fi
}

print_info "Starting deployment process..."
print_info "Plan file will be: ${PLAN_FILE}"

# Step 0: Collect required input values
print_info "Step 0: Collecting required configuration values..."
echo ""
print_info "Please provide the following segment configuration:"

# Prompt for segment_start_ip_addr
prompt_input "Enter segment start IP address (e.g., 10.1.1.1)" "SEGMENT_START_IP" "validate_ip"
update_tfvars "segment_start_ip_addr" "$SEGMENT_START_IP"

# Prompt for segment_end_ip_addr
prompt_input "Enter segment end IP address, exclude gateway IP (e.g., 10.1.1.253)" "SEGMENT_END_IP" "validate_ip"
update_tfvars "segment_end_ip_addr" "$SEGMENT_END_IP"

# Prompt for segment_gateway_cidr
prompt_input "Enter segment gateway in CIDR format (e.g., 10.1.1.254/24)" "SEGMENT_GATEWAY_CIDR" "validate_cidr"
update_tfvars "segment_gateway_cidr" "$SEGMENT_GATEWAY_CIDR"

# Prompt for segment_type (must be "vlan" or "overlay")
while true; do
    echo -ne "${YELLOW}[INPUT]${NC} Enter segment type (vlan or overlay): "
    read -r SEGMENT_TYPE
    SEGMENT_TYPE=$(echo "$SEGMENT_TYPE" | tr '[:upper:]' '[:lower:]')
    if [ "$SEGMENT_TYPE" == "vlan" ] || [ "$SEGMENT_TYPE" == "overlay" ]; then
        update_tfvars "segment_type" "$SEGMENT_TYPE"
        break
    else
        print_error "Segment type must be either 'vlan' or 'overlay'. Please try again."
    fi
done

# Prompt for segment_vlan_id only if segment_type is "vlan"
if [ "$SEGMENT_TYPE" == "vlan" ]; then
    prompt_input "Enter VLAN ID (must be between 105 and 150)" "SEGMENT_VLAN_ID" "validate_vlan_id"
    update_tfvars "segment_vlan_id" "$SEGMENT_VLAN_ID"
else
    # For overlay, set vlan_id to empty string
    update_tfvars "segment_vlan_id" ""
fi

echo ""
print_info "Configuration values collected and updated in terraform.tfvars"
print_info "  - Segment Start IP: ${SEGMENT_START_IP}"
print_info "  - Segment End IP: ${SEGMENT_END_IP}"
print_info "  - Segment Gateway CIDR: ${SEGMENT_GATEWAY_CIDR}"
print_info "  - Segment Type: ${SEGMENT_TYPE}"
if [ "$SEGMENT_TYPE" == "vlan" ]; then
    print_info "  - VLAN ID: ${SEGMENT_VLAN_ID}"
fi
echo ""

# Step 1: Deploy resources in terraform-vCD
print_info "Step 1: Deploying resources in terraform-vCD directory..."
cd "${TERRAFORM_VCD_DIR}"

print_info "Running terraform init..."
terraform init

print_info "Running terraform plan..."
terraform plan -out="${PLAN_FILE}"

print_info "Running terraform apply..."
terraform apply "${PLAN_FILE}"

print_info "Resources created successfully in terraform-vCD"

# Step 2: Get t1_id from output
print_info "Step 2: Getting t1_id from terraform output..."

# Try to get t1_id from the root output (first value from the map)
# The output format is: t1_id = { "vdc_name" = "t1_id_value" }
T1_ID=$(terraform output -raw t1_id 2>/dev/null | jq -r 'to_entries[0].value' 2>/dev/null || echo "")

# If that doesn't work, try getting from t1_ids output
if [ -z "$T1_ID" ] || [ "$T1_ID" == "null" ]; then
    # Get the first org's first vdc's t1_id
    T1_ID=$(terraform output -json t1_ids 2>/dev/null | jq -r 'to_entries[0].value | to_entries[0].value' 2>/dev/null || echo "")
fi

# If still empty, try getting from module outputs directly
if [ -z "$T1_ID" ] || [ "$T1_ID" == "null" ]; then
    # Try to get from module.orgs output
    OUTPUT_JSON=$(terraform output -json 2>/dev/null)
    T1_ID=$(echo "$OUTPUT_JSON" | jq -r 'to_entries[] | select(.key == "t1_id" or .key == "t1_ids") | .value.value | if type == "object" then to_entries[0].value | to_entries[0].value else . end' 2>/dev/null || echo "")
fi

# If T1_ID is still empty, prompt user
if [ -z "$T1_ID" ] || [ "$T1_ID" == "null" ]; then
    print_warn "Could not automatically extract t1_id from outputs."
    print_info "Available outputs:"
    terraform output
    print_info "Please enter the t1_id value manually:"
    read -r T1_ID
fi

if [ -z "$T1_ID" ]; then
    print_error "t1_id is required but could not be determined. Exiting."
    exit 1
fi

print_info "Found t1_id: ${T1_ID}"

# Step 3: Get org_name for display_name (optional, but helpful)
print_info "Step 3: Getting org_name for display_name..."
# Try to get org_name from the first org module output
ORG_NAME=$(terraform output -json 2>/dev/null | jq -r 'to_entries[] | select(.key | contains("org_name")) | .value.value' 2>/dev/null | head -1 || echo "")

# If org_name not found, try from module outputs or t1_ids keys
if [ -z "$ORG_NAME" ] || [ "$ORG_NAME" == "null" ]; then
    # Get the first key from t1_ids output (which is the org name)
    ORG_NAME=$(terraform output -json t1_ids 2>/dev/null | jq -r 'keys[0]' 2>/dev/null || echo "")
fi

# Step 4: Switch to terraform-import-resources and update display_name
print_info "Step 4: Updating display_name in terraform-import-resources/main.tf..."
cd "${TERRAFORM_IMPORT_DIR}"

# Create display_name - use org_name if available, otherwise just use T1-{t1_id}
if [ -n "$ORG_NAME" ] && [ "$ORG_NAME" != "null" ]; then
    DISPLAY_NAME="${ORG_NAME}-T1-${T1_ID}"
else
    DISPLAY_NAME="T1-${T1_ID}"
fi

print_info "Setting display_name to: ${DISPLAY_NAME}"

# Use sed to replace the empty display_name
# This will replace: display_name  = "" with: display_name  = "${DISPLAY_NAME}"
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS uses BSD sed
    sed -i '' "s/display_name  = \"\"/display_name  = \"${DISPLAY_NAME}\"/" main.tf
else
    # Linux uses GNU sed
    sed -i "s/display_name  = \"\"/display_name  = \"${DISPLAY_NAME}\"/" main.tf
fi

print_info "display_name updated successfully"

# Step 5: Run terraform commands in terraform-import-resources
print_info "Step 5: Running terraform commands in terraform-import-resources directory..."

print_info "Running terraform init..."
terraform init

print_info "Running terraform import..."
terraform import nsxt_policy_tier1_gateway.enable_t1_adv "/infra/tier-1s/${T1_ID}"

if [ $? -ne 0 ]; then
    print_error "Terraform import failed. Please check the t1_id and try again."
    exit 1
fi

print_info "Running terraform plan..."
terraform plan -out="${PLAN_FILE}"

print_info "Running terraform apply..."
terraform apply "${PLAN_FILE}"

print_info "Deployment and import process completed successfully!"
print_info "Summary:"
print_info "  - Resources created in: ${TERRAFORM_VCD_DIR}"
print_info "  - Resources imported in: ${TERRAFORM_IMPORT_DIR}"
print_info "  - T1 Gateway ID: ${T1_ID}"
print_info "  - Display Name: ${DISPLAY_NAME}"

