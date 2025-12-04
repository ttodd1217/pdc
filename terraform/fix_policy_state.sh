#!/bin/bash
# Script to fix IAM role policy state issues
# This removes policies from Terraform state if they exist in AWS but cause conflicts

set +e

echo "Checking and fixing IAM role policy state issues..."

# Function to remove a policy from Terraform state if it exists
remove_from_state_if_needed() {
    local resource_name=$1
    local role_name=$2
    local policy_name=$3
    
    echo ""
    echo "=== Checking: $resource_name ==="
    
    # Check if resource is in Terraform state
    if terraform state show "$resource_name" > /dev/null 2>&1; then
        echo "Resource $resource_name is in Terraform state."
        
        # Check if policy exists in AWS
        if aws iam get-role-policy --role-name "$role_name" --policy-name "$policy_name" > /dev/null 2>&1; then
            echo "Policy $policy_name exists in AWS."
            echo "Removing $resource_name from Terraform state to prevent conflicts..."
            
            if terraform state rm "$resource_name" 2>&1; then
                echo "✓ Removed $resource_name from state. It will be imported fresh."
                return 0
            else
                echo "⚠ Failed to remove from state. Continuing..."
                return 1
            fi
        else
            echo "Policy $policy_name does not exist in AWS. Keeping in state."
            return 0
        fi
    else
        echo "Resource $resource_name is not in Terraform state. Nothing to do."
        return 0
    fi
}

# Remove policies from state if they're causing conflicts
remove_from_state_if_needed "aws_iam_role_policy.ecs_task_execution_secrets" "pdc-ecs-task-execution-role" "pdc-ecs-task-execution-secrets"
remove_from_state_if_needed "aws_iam_role_policy.ecs_task_permissions" "pdc-ecs-task-app-role" "pdc-ecs-task-permissions"
remove_from_state_if_needed "aws_iam_role_policy.eventbridge_ecs" "pdc-eventbridge-ecs-role" "pdc-eventbridge-ecs-policy"

echo ""
echo "=== State cleanup completed ==="
echo "Now run the import script to re-import the policies."

exit 0


