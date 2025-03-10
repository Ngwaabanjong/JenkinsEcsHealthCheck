# Jenkins ECS Health heck
- This is a poc Jenkins pipeline to check ECS containers.

## What it does:
- Update the ECS Service to deploy new tasks.
- Check status of the task and report back to the pipeline.
- Fail the pipeline if the tasks are not healthy in 3 minutes
- Pass the pipeline if the tasks are healthy. 

