#!/bin/bash

# Create snapshots of internal instances after init script completion
# Usage: ./create_snapshots.sh

set -e

echo "Creating snapshots of internal instances..."

# Get internal instance IDs from Terraform output
INSTANCE_IDS=$(terraform output -json internal_instance_ids | jq -r '.[]')

if [ -z "$INSTANCE_IDS" ]; then
    echo "Error: No internal instances found"
    exit 1
fi

# Create snapshots for each instance
for INSTANCE_ID in $INSTANCE_IDS; do
    echo "Processing instance: $INSTANCE_ID"

    # Get volume IDs attached to the instance
    VOLUME_IDS=$(aws ec2 describe-volumes \
        --filters "Name=attachment.instance-id,Values=$INSTANCE_ID" \
        --query "Volumes[*].VolumeId" \
        --output text)

    for VOLUME_ID in $VOLUME_IDS; do
        echo "Creating snapshot for volume: $VOLUME_ID"

        # Create snapshot
        SNAPSHOT_ID=$(aws ec2 create-snapshot \
            --volume-id "$VOLUME_ID" \
            --description "Hardening exercise - Initial setup completed - $INSTANCE_ID" \
            --tag-specifications "ResourceType=snapshot,Tags=[{Key=Name,Value=hardening-initial-${INSTANCE_ID}-${VOLUME_ID}},{Key=Purpose,Value=recovery},{Key=InstanceId,Value=$INSTANCE_ID}]" \
            --query "SnapshotId" \
            --output text)

        echo "Created snapshot: $SNAPSHOT_ID"
    done
done

echo ""
echo "Snapshot creation initiated. You can check the status with:"
echo "aws ec2 describe-snapshots --owner-ids self --query 'Snapshots[?contains(Description, \`Hardening exercise\`)]'"
