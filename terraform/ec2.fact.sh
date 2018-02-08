#!/bin/bash

set -e

INSTANCE_ID="$(curl -sf http://169.254.169.254/latest/meta-data/instance-id)"
REGION="$(curl -sf http://169.254.169.254/latest/dynamic/instance-identity/document | jq -r '.region')"
NAME=$(ec2-describe-tags --filter "resource-type=instance" --filter "resource-id=${INSTANCE_ID}" --filter "key=Name" --region "${REGION}" | cut -f 5)

echo "{
  \"tags\": {
    \"name\": \"${NAME}\"
  }
"}