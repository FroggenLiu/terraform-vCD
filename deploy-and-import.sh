#!/bin/bash

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="${SCRIPT_DIR}/terraform-vCD"
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
    local file_path="${TERRAFORM_DIR}/terraform.tfvars"
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

# Function to update the org key name in the orgs map
update_org_key_name() {
    local file_path="${TERRAFORM_DIR}/terraform.tfvars"
    local new_key=$1
    
    # Check if file exists
    if [ ! -f "$file_path" ]; then
        print_error "terraform.tfvars file not found at ${file_path}"
        exit 1
    fi
    
    # Use awk to find and replace the org key name
    # Pattern: after "orgs = {" find the first line with "  KEY = {" and replace KEY
    awk -v newkey="$new_key" '
        BEGIN { in_orgs = 0; updated = 0 }
        /^orgs[[:space:]]*=[[:space:]]*\{/ { in_orgs = 1 }
        in_orgs && !updated && /^[[:space:]]+[^[:space:]#]+[[:space:]]*=[[:space:]]*\{/ {
            # Extract indentation and rest of line
            match($0, /^([[:space:]]+)([^[:space:]#]+)([[:space:]]*=[[:space:]]*\{.*)/, arr)
            if (arr[2] != "") {
                $0 = arr[1] newkey arr[3]
                updated = 1
            }
        }
        { print }
    ' "$file_path" > "${file_path}.tmp" && mv "${file_path}.tmp" "$file_path"
    
    if [ $? -ne 0 ]; then
        print_error "Failed to update org key name in terraform.tfvars"
        exit 1
    fi
}

# Function to update nested values in orgs block with context using awk
update_orgs_tfvars() {
    local file_path="${TERRAFORM_DIR}/terraform.tfvars"
    local pattern=$1
    local value=$2
    local context=$3  # Context to find the right block (e.g., "vdcs = " or org key name for org-level fields)
    
    # Check if file exists
    if [ ! -f "$file_path" ]; then
        print_error "terraform.tfvars file not found at ${file_path}"
        exit 1
    fi
    
    # Escape special characters in value for awk replacement
    local escaped_value=$(printf '%s\n' "$value" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g')
    
    # Use awk to update within context
    if [ -n "$context" ]; then
      if [[ "$context" != "vdcs ="* ]] && [[ "$context" != "storage_profile"* ]]; then
        awk -v pattern="$pattern" -v newval="$escaped_value" -v orgkey="$context" '
          BEGIN {
            in_org = 0
            updated = 0
            stop_update = 0
          }

          # Enter the org block
          $0 ~ "^[[:space:]]*\"" orgkey "\"[[:space:]]*=[[:space:]]*\\{" {
            in_org = 1
            stop_update = 0
          }
          
          # Detect nested blocks universally
          in_org && $0 ~ /^[[:space:]]*(vdcs|users|custom_roles)[[:space:]]*=/ {
            stop_update = 1
          }

          # Update only IF:
          #   - in org block
          #   - not inside nested blocks (vdcs, users, custom_roles)
          #   - line contains "pattern"
          #   - and not updated before
          in_org && !stop_update && !updated && $0 ~ /^[[:space:]]*pattern[[:space:]]*=/ {
            sub(/"[^"]*"/, "\"" newval "\"")
            updated = 1
          }
          { print }
          '"$file_path" > "${file_path}.tmp" && mv "${file_path}.tmp" "$file_path"
      else
        # Context is a block identifier (vdcs, storage_profile, etc.)
        local escaped_context=$(printf '%s\n' "$context" | sed 's/[[\.*^$()+?{|]/\\&/g')
        # Update pattern within the specified context block
        awk -v pattern="$pattern" -v newval="$escaped_value" -v ctx="$escaped_context" '
          BEGIN { in_context = 0; updated = 0 }
          $0 ~ ctx { in_context = 1 }
          in_context && /^[[:space:]]*'"$pattern"'[[:space:]]*=[[:space:]]*"/ && !updated {
            sub(/"[^"]*"/, "\"" newval "\"")
            updated = 1
            in_context = 0
          }
          { print }
          ' "$file_path" > "${file_path}.tmp" && mv "${file_path}.tmp" "$file_path"
      fi
    else
      # Simple pattern match (for unique fields - but this is risky, should use context)
      local escaped_value_sed=$(printf '%s\n' "$value" | sed 's/\\/\\\\/g' | sed 's/&/\\&/g' | sed 's/|/\\|/g')
      if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "s|^\([[:space:]]*\)${pattern}[[:space:]]*=[[:space:]]*\".*\"|\1${pattern} = \"${escaped_value_sed}\"|" "$file_path"
      else
        sed -i "s|^\([[:space:]]*\)${pattern}[[:space:]]*=[[:space:]]*\".*\"|\1${pattern} = \"${escaped_value_sed}\"|" "$file_path"
      fi
    fi
    
    if [ $? -ne 0 ]; then
        print_error "Failed to update ${pattern} in terraform.tfvars"
        exit 1
    fi
}

print_info "Starting deployment process..."
print_info "Plan file will be: ${PLAN_FILE}"

# Step 0: Collect required input values
print_info "Step 0: Collecting required configuration values..."
echo ""

# Prompt for org configuration
print_info "Please provide the following organization configuration:"

prompt_input "Enter organization name (e.g., XXX-MAIN.OL.IT)" "ORG_NAME" ""
# Update the org key name in the orgs map
update_org_key_name "\"$ORG_NAME\""

prompt_input "Enter organization full name (e.g., XXX-MAIN.OL.IT-XXX系統)" "ORG_FULL_NAME" ""
# Update org-level full_name (not users block full_name) - use org key as context
update_orgs_tfvars "full_name" "$ORG_FULL_NAME" "$ORG_NAME"

# Auto-generate VDC name from org name
VDC_NAME="${ORG_NAME}-VDC"
print_info "Auto-generated VDC name: ${VDC_NAME}"
update_orgs_tfvars "name" "$VDC_NAME" "vdcs ="

prompt_input "Enter provider VDC name (tf-cl01 or tf-cl02)" "PROVIDER_VDC_NAME" ""
update_orgs_tfvars "provider_vdc_name" "$PROVIDER_VDC_NAME" "vdcs ="

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
print_info "Organization Configuration:"
print_info "  - Organization Name: ${ORG_NAME}"
print_info "  - Organization Full Name: ${ORG_FULL_NAME}"
print_info "  - VDC Name: ${VDC_NAME}"
print_info "  - Provider VDC Name: ${PROVIDER_VDC_NAME}"
echo ""
print_info "Segment Configuration:"
print_info "  - Segment Start IP: ${SEGMENT_START_IP}"
print_info "  - Segment End IP: ${SEGMENT_END_IP}"
print_info "  - Segment Gateway CIDR: ${SEGMENT_GATEWAY_CIDR}"
print_info "  - Segment Type: ${SEGMENT_TYPE}"
if [ "$SEGMENT_TYPE" == "vlan" ]; then
    print_info "  - VLAN ID: ${SEGMENT_VLAN_ID}"
fi
echo ""

# Confirmation step before proceeding
print_info "=========================================="
print_info "Configuration Summary:"
print_info "=========================================="
print_info "Organization Configuration:"
print_info "  Organization Name:      ${ORG_NAME}"
print_info "  Organization Full Name: ${ORG_FULL_NAME}"
print_info "  VDC Name:               ${VDC_NAME}"
print_info "  Provider VDC Name:      ${PROVIDER_VDC_NAME}"
print_info "  Network Pool Name:      ${NETWORK_POOL_NAME}"
print_info "  Storage Profile Name:   ${STORAGE_PROFILE_NAME}"
echo ""
print_info "Segment Configuration:"
print_info "  Segment Start IP:     ${SEGMENT_START_IP}"
print_info "  Segment End IP:       ${SEGMENT_END_IP}"
print_info "  Segment Gateway CIDR: ${SEGMENT_GATEWAY_CIDR}"
print_info "  Segment Type:         ${SEGMENT_TYPE}"
if [ "$SEGMENT_TYPE" == "vlan" ]; then
    print_info "  VLAN ID:              ${SEGMENT_VLAN_ID}"
fi
print_info "  Plan File:            ${PLAN_FILE}"
print_info "=========================================="
echo ""

# Prompt for confirmation
while true; do
    echo -ne "${YELLOW}[CONFIRM]${NC} Do you want to proceed with deployment? (y/n): "
    read -r CONFIRM
    CONFIRM=$(echo "$CONFIRM" | tr '[:upper:]' '[:lower:]')
    if [ "$CONFIRM" == "y" ] || [ "$CONFIRM" == "yes" ]; then
        print_info "Proceeding with deployment..."
        echo ""
        break
    elif [ "$CONFIRM" == "n" ] || [ "$CONFIRM" == "no" ]; then
        print_info "Deployment cancelled by user."
        exit 0
    else
        print_error "Please enter 'y' or 'n'."
    fi
done

# Step 1: Deploy resources in terraform-vCD
print_info "Step 1: Deploying resources in terraform-vCD directory..."
cd "${TERRAFORM_DIR}"

print_info "Running terraform init..."
terraform init

print_info "Running terraform plan..."
terraform plan -out="${PLAN_FILE}"

print_info "Running terraform apply..."
terraform apply "${PLAN_FILE}"

print_info "Resources created successfully in terraform-vCD"

# Steps 2-5 are only needed for VLAN segments
if [ "$SEGMENT_TYPE" == "vlan" ]; then
    # Step 2: Get t1_display_name from output
    print_info "Step 2: Getting t1_display_name from terraform output..."

    # Try to get t1_display_name from the root output (first value from the map)
    # The output format is: t1_display_name = { "vdc_name" = "display_name_value" }
    DISPLAY_NAME=$(terraform output -raw t1_display_name 2>/dev/null | jq -r 'to_entries[0].value' 2>/dev/null || echo "")

    # If that doesn't work, try getting from t1_display_names output
    if [ -z "$DISPLAY_NAME" ] || [ "$DISPLAY_NAME" == "null" ]; then
        # Get the first org's first vdc's t1_display_name
        DISPLAY_NAME=$(terraform output -json t1_display_names 2>/dev/null | jq -r 'to_entries[0].value | to_entries[0].value' 2>/dev/null || echo "")
    fi

    # If still empty, try getting from module outputs directly
    if [ -z "$DISPLAY_NAME" ] || [ "$DISPLAY_NAME" == "null" ]; then
        # Try to get from module.orgs output
        OUTPUT_JSON=$(terraform output -json 2>/dev/null)
        DISPLAY_NAME=$(echo "$OUTPUT_JSON" | jq -r 'to_entries[] | select(.key == "t1_display_name" or .key == "t1_display_names") | .value.value | if type == "object" then to_entries[0].value | to_entries[0].value else . end' 2>/dev/null || echo "")
    fi

    # If DISPLAY_NAME is still empty, prompt user
    if [ -z "$DISPLAY_NAME" ] || [ "$DISPLAY_NAME" == "null" ]; then
        print_warn "Could not automatically extract t1_display_name from outputs."
        print_info "Available outputs:"
        terraform output
        print_info "Please enter the t1_display_name value manually:"
        read -r DISPLAY_NAME
    fi

    if [ -z "$DISPLAY_NAME" ]; then
        print_error "t1_display_name is required but could not be determined. Exiting."
        exit 1
    fi

    print_info "Found t1_display_name: ${DISPLAY_NAME}"

    # Step 3: Get t1_path from output (needed for import command)
    print_info "Step 3: Getting t1_path from terraform output (needed for import)..."

    # Try to get t1_path from the root output (first value from the map)
    # The output format is: t1_path = { "vdc_name" = "t1_path_value" }
    T1_PATH=$(terraform output -raw t1_path 2>/dev/null | jq -r 'to_entries[0].value' 2>/dev/null || echo "")

    # If that doesn't work, try getting from t1_paths output
    if [ -z "$T1_PATH" ] || [ "$T1_PATH" == "null" ]; then
        # Get the first org's first vdc's t1_path
        T1_PATH=$(terraform output -json t1_paths 2>/dev/null | jq -r 'to_entries[0].value | to_entries[0].value' 2>/dev/null || echo "")
    fi

    # If still empty, try getting from module outputs directly
    if [ -z "$T1_PATH" ] || [ "$T1_PATH" == "null" ]; then
        # Try to get from module.orgs output
        OUTPUT_JSON=$(terraform output -json 2>/dev/null)
        T1_PATH=$(echo "$OUTPUT_JSON" | jq -r 'to_entries[] | select(.key == "t1_path" or .key == "t1_paths") | .value.value | if type == "object" then to_entries[0].value | to_entries[0].value else . end' 2>/dev/null || echo "")
    fi

    # If T1_PATH is still empty, prompt user
    if [ -z "$T1_PATH" ] || [ "$T1_PATH" == "null" ]; then
        print_warn "Could not automatically extract t1_path from outputs."
        print_info "Available outputs:"
        terraform output
        print_info "Please enter the t1_path value manually:"
        read -r T1_PATH
    fi

    if [ -z "$T1_PATH" ]; then
        print_error "t1_path is required for import but could not be determined. Exiting."
        exit 1
    fi

    print_info "Found t1_path: ${T1_PATH}"

    # Step 4: Switch to terraform-import-resources and update display_name
    print_info "Step 4: Updating display_name in terraform-import-resources/main.tf..."
    cd "${TERRAFORM_IMPORT_DIR}"

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
    terraform import nsxt_policy_tier1_gateway.enable_t1_adv "${T1_PATH}"

    if [ $? -ne 0 ]; then
        print_error "Terraform import failed. Please check the t1_path and try again."
        exit 1
    fi

    print_info "Running terraform plan..."
    terraform plan -out="${PLAN_FILE}"

    print_info "Running terraform apply..."
    terraform apply "${PLAN_FILE}"
else
    print_info "Skipping steps 2-5 (import process) - not needed for overlay segments"
fi

print_info "Deployment and import process completed successfully!"
print_info "Summary:"
print_info "  - Resources created in: ${TERRAFORM_DIR}"
if [ "$SEGMENT_TYPE" == "vlan" ]; then
    print_info "  - Resources imported in: ${TERRAFORM_IMPORT_DIR}"
    print_info "  - T1 Gateway Path: ${T1_PATH}"
    print_info "  - Display Name: ${DISPLAY_NAME}"
fi

