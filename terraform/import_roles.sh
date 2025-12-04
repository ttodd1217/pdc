#!/bin/bash
# Script to import existing IAM roles into Terraform state
# This handles the case where roles were created outside of Terraform

set +e  # Don't exit on error - we want to continue even if some imports fail

echo "Attempting to import existing IAM roles into Terraform state..."

# Function to import a role if it exists
import_role() {
    local resource_name=$1
    local role_name=$2
    
    echo ""
    echo "=== Processing role: $role_name ==="
    
    # Check if role exists in AWS
    if ! aws iam get-role --role-name "$role_name" > /dev/null 2>&1; then
        echo "Role $role_name does not exist in AWS. It will be created by Terraform."
        return 0
    fi
    
    echo "Role $role_name exists in AWS."
    
    # Check if already in Terraform state
    if terraform state show "$resource_name" > /dev/null 2>&1; then
        echo "Role $role_name is already in Terraform state. Skipping import."
        return 0
    fi
    
    # Attempt to import
    echo "Importing $role_name as $resource_name..."
    if terraform import "$resource_name" "$role_name" 2>&1; then
        echo "✓ Successfully imported $role_name"
        return 0
    else
        echo "⚠ Warning: Failed to import $role_name. This may be expected if:"
        echo "  - The role configuration doesn't match exactly"
        echo "  - The role is managed by another Terraform configuration"
        echo "  - There are permission issues"
        return 1
    fi
}

# Function to import a role policy if it exists
import_role_policy() {
    local resource_name=$1
    local role_name=$2
    local policy_name=$3
    
    echo ""
    echo "=== Processing policy: $policy_name on role $role_name ==="
    
    # Check if policy exists in AWS
    if ! aws iam get-role-policy --role-name "$role_name" --policy-name "$policy_name" > /dev/null 2>&1; then
        echo "Policy $policy_name does not exist on role $role_name. It will be created by Terraform."
        return 0
    fi
    
    echo "Policy $policy_name exists on role $role_name."
    
    # Check if already in Terraform state
    if terraform state show "$resource_name" > /dev/null 2>&1; then
        echo "Policy $policy_name is already in Terraform state. Skipping import."
        return 0
    fi
    
    # Attempt to import (format: role_name:policy_name)
    echo "Importing $policy_name as $resource_name..."
    if terraform import "$resource_name" "${role_name}:${policy_name}" 2>&1; then
        echo "✓ Successfully imported $policy_name"
        return 0
    else
        echo "⚠ Warning: Failed to import $policy_name. This may be expected if:"
        echo "  - The policy configuration doesn't match exactly"
        echo "  - The policy is managed by another Terraform configuration"
        echo "  - There are permission issues"
        return 1
    fi
}

# Import the three IAM roles
IMPORT_ERRORS=0

import_role "aws_iam_role.ecs_task_execution_role" "pdc-ecs-task-execution-role" || IMPORT_ERRORS=$((IMPORT_ERRORS + 1))
import_role "aws_iam_role.ecs_task_role" "pdc-ecs-task-app-role" || IMPORT_ERRORS=$((IMPORT_ERRORS + 1))
import_role "aws_iam_role.eventbridge_ecs" "pdc-eventbridge-ecs-role" || IMPORT_ERRORS=$((IMPORT_ERRORS + 1))

# Import the IAM role policies
import_role_policy "aws_iam_role_policy.ecs_task_execution_secrets" "pdc-ecs-task-execution-role" "pdc-ecs-task-execution-secrets" || IMPORT_ERRORS=$((IMPORT_ERRORS + 1))
import_role_policy "aws_iam_role_policy.ecs_task_permissions" "pdc-ecs-task-app-role" "pdc-ecs-task-permissions" || IMPORT_ERRORS=$((IMPORT_ERRORS + 1))
import_role_policy "aws_iam_role_policy.eventbridge_ecs" "pdc-eventbridge-ecs-role" "pdc-eventbridge-ecs-policy" || IMPORT_ERRORS=$((IMPORT_ERRORS + 1))

echo ""
echo "=== IAM role import process completed ==="
if [ $IMPORT_ERRORS -gt 0 ]; then
    echo "⚠ Some imports had warnings/errors, but continuing..."
    echo "Terraform will attempt to create or update resources as needed."
fi

exit 0  # Always exit successfully so the workflow continues

