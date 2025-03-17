#!/bin/bash

# Variables
CLUSTER_NAME="x-test-ecs-cluster"  # Change to your cluster name
SERVICE_NAME="x-test-service"       # Change to your ECS service name
TIMEOUT=180  # 3 minutes in seconds
INTERVAL=10  # Check every 10 seconds
MAX_RETRIES=2  # Number of retry cycles
ATTEMPT=1

check_latest_task() {
    local elapsed=0
    echo "Checking latest deployed ECS task in cluster: $CLUSTER_NAME (Attempt $ATTEMPT of $MAX_RETRIES)"

    # Get the latest task definition ARN deployed by Terraform
    LATEST_TASK_DEF=$(aws ecs describe-services --cluster "$CLUSTER_NAME" --services "$SERVICE_NAME" --query 'services[0].taskDefinition' --output text)

    if [ -z "$LATEST_TASK_DEF" ]; then
        echo "❌ No task definition found for service: $SERVICE_NAME"
        return 1
    fi

    echo "Latest deployed task definition: $LATEST_TASK_DEF"

    # Extract task family name (e.g., prod-di-status)
    TASK_FAMILY=$(echo "$LATEST_TASK_DEF" | cut -d':' -f1)

    # Start checking for the latest running task
    while [ $elapsed -lt $TIMEOUT ]; do
        TASK_ARN=$(aws ecs list-tasks --cluster "$CLUSTER_NAME" --service-name "$SERVICE_NAME" --query 'taskArns[-1]' --output text)

        if [ "$TASK_ARN" == "None" ]; then
            echo "No running tasks found, retrying..."
            sleep $INTERVAL
            ((elapsed+=$INTERVAL))
            continue
        fi

        echo "Latest running task ARN: $TASK_ARN"

        # Get the task definition of the running task
        RUNNING_TASK_DEF=$(aws ecs describe-tasks --cluster "$CLUSTER_NAME" --tasks "$TASK_ARN" --query 'tasks[0].taskDefinitionArn' --output text)

        echo "Running task definition: $RUNNING_TASK_DEF"

        # Ensure we're checking only the latest deployed task
        if [ "$RUNNING_TASK_DEF" == "$LATEST_TASK_DEF" ]; then
            STATUS=$(aws ecs describe-tasks --cluster "$CLUSTER_NAME" --tasks "$TASK_ARN" --query 'tasks[0].lastStatus' --output text)
            echo "Task Status: $STATUS"

            if [ "$STATUS" == "RUNNING" ]; then
                echo "✅ Latest task is running successfully. Pipeline passed."
                return 0
            fi
        else
            echo "⚠️ The latest deployed task ($LATEST_TASK_DEF) is not running. Checking rollback..."

            # Get the previous task definition
            PREVIOUS_TASK_DEF=$(aws ecs list-task-definitions --family-prefix "$TASK_FAMILY" --sort DESC --query 'taskDefinitionArns[1]' --output text)

            if [ -z "$PREVIOUS_TASK_DEF" ]; then
                echo "❌ No previous healthy task definition found."
                return 1
            fi

            echo "Previous healthy task definition: $PREVIOUS_TASK_DEF"

            # Check if the previous task is now running (indicating rollback)
            ROLLBACK_TASK_ARN=$(aws ecs list-tasks --cluster "$CLUSTER_NAME" --service-name "$SERVICE_NAME" --query 'taskArns[-1]' --output text)
            ROLLBACK_TASK_DEF=$(aws ecs describe-tasks --cluster "$CLUSTER_NAME" --tasks "$ROLLBACK_TASK_ARN" --query 'tasks[0].taskDefinitionArn' --output text)

            if [ "$ROLLBACK_TASK_DEF" == "$PREVIOUS_TASK_DEF" ]; then
                echo "🚨 Latest task failed. Service rolled back to: $PREVIOUS_TASK_DEF"
                return 1
            fi
        fi

        sleep $INTERVAL
        ((elapsed+=$INTERVAL))
    done

    echo "❌ Task failed to become healthy within 3 minutes."
    return 1
}

# Run the check with retry logic
while [ $ATTEMPT -le $MAX_RETRIES ]; do
    check_latest_task
    RESULT=$?

    if [ $RESULT -eq 0 ]; then
        exit 0  # Pass pipeline
    fi

    if [ $ATTEMPT -eq $MAX_RETRIES ]; then
        echo "❌ Task failed after $MAX_RETRIES attempts. Failing pipeline."
        exit 1
    fi

    echo "🔄 Retrying in 3 minutes..."
    sleep $TIMEOUT
    ((ATTEMPT++))
done
