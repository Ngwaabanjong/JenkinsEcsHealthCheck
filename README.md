# Jenkins ECS Health Check
- This is a poc Jenkins pipeline to check ECS containers.

## What it does:
- Update the ECS Service to provision new tasks.
- Check status of the task and report back to the pipeline.
- Fail the pipeline if the tasks are not healthy in 3 minutes
- Pass the pipeline if the tasks are healthy.

## Script 2:
- If the latest task fails to start, the pipeline will fail after script tries the 2nd time.
- If ECS rolls back to the previous task, the pipeline will fail.
- If the latest task becomes healthy within 3 minutes, the pipeline passes.

