#!/bin/bash

# Variables
CLUSTER_NAME="x-test-ecs-cluster"  # Change to your cluster name
SERVICE_NAME="x-test-service"       # Change to your ECS service name
TIMEOUT=180  # 3 minutes in seconds
INTERVAL=10  # Check every 10 seconds
ELAPSED=0

echo "Checking for new ECS tasks in cluster: $CLUSTER_NAME"

# Get the task ARN with the highest number (latest task)
while [ $ELAPSED -lt $TIMEOUT ]; do
    TASK_ARN=$(aws ecs list-tasks --cluster "$CLUSTER_NAME" --service-name "$SERVICE_NAME" --query 'taskArns[-1]' --output text)

    if [ "$TASK_ARN" == "None" ]; then
        echo "No running tasks found, retrying..."
        sleep $INTERVAL
        ((ELAPSED+=$INTERVAL))
        continue
    fi

    echo "Latest task ARN: $TASK_ARN"

    # Get task status
    STATUS=$(aws ecs describe-tasks --cluster "$CLUSTER_NAME" --tasks "$TASK_ARN" --query 'tasks[0].lastStatus' --output text)

    echo "Task Status: $STATUS"

    if [ "$STATUS" == "RUNNING" ]; then
        echo "✅ Task is running successfully. Pipeline passed."
        exit 0
    fi

    sleep $INTERVAL
    ((ELAPSED+=$INTERVAL))
done

echo "❌ Task failed to become healthy within 3 minutes. Failing pipeline."
exit 1
