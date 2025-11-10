#!/bin/bash

# Restore internal instances from snapshots
# Usage: ./restore_from_snapshot.sh <instance-id>

set -e

if [ $# -eq 0 ]; then
    echo "Usage: $0 <instance-id>"
    echo ""
    echo "Available instances:"
    terraform output -json all_instance_info | jq -r '.internal_instances | to_entries[] | "\(.key): \(.value.id) (\(.value.private_ip))"'
    exit 1
fi

INSTANCE_ID=$1

echo "Restoring instance: $INSTANCE_ID"

# Stop the instance
echo "Stopping instance..."
aws ec2 stop-instances --instance-ids "$INSTANCE_ID"
aws ec2 wait instance-stopped --instance-ids "$INSTANCE_ID"
echo "Instance stopped."

# Get current volumes
echo "Getting current volumes..."
ATTACHMENTS=$(aws ec2 describe-volumes \
    --filters "Name=attachment.instance-id,Values=$INSTANCE_ID" \
    --query "Volumes[*].[VolumeId,Attachments[0].Device]" \
    --output text)

# Process each volume
while IFS=$'\t' read -r VOLUME_ID DEVICE; do
    echo ""
    echo "Processing volume: $VOLUME_ID (device: $DEVICE)"

    # Find the latest snapshot for this instance
    SNAPSHOT_ID=$(aws ec2 describe-snapshots \
        --owner-ids self \
        --filters "Name=tag:InstanceId,Values=$INSTANCE_ID" \
        --query "Snapshots | sort_by(@, &StartTime) | [-1].SnapshotId" \
        --output text)

    if [ "$SNAPSHOT_ID" = "None" ] || [ -z "$SNAPSHOT_ID" ]; then
        echo "Warning: No snapshot found for instance $INSTANCE_ID, skipping..."
        continue
    fi

    echo "Found snapshot: $SNAPSHOT_ID"

    # Detach current volume
    echo "Detaching current volume..."
    aws ec2 detach-volume --volume-id "$VOLUME_ID"
    sleep 10

    # Get availability zone
    AZ=$(aws ec2 describe-instances \
        --instance-ids "$INSTANCE_ID" \
        --query "Reservations[0].Instances[0].Placement.AvailabilityZone" \
        --output text)

    # Create new volume from snapshot
    echo "Creating new volume from snapshot..."
    NEW_VOLUME_ID=$(aws ec2 create-volume \
        --snapshot-id "$SNAPSHOT_ID" \
        --availability-zone "$AZ" \
        --volume-type gp3 \
        --tag-specifications "ResourceType=volume,Tags=[{Key=Name,Value=hardening-restored-$INSTANCE_ID}]" \
        --query "VolumeId" \
        --output text)

    echo "Created new volume: $NEW_VOLUME_ID"

    # Wait for volume to be available
    echo "Waiting for volume to be available..."
    aws ec2 wait volume-available --volume-ids "$NEW_VOLUME_ID"

    # Attach new volume
    echo "Attaching new volume..."
    aws ec2 attach-volume \
        --volume-id "$NEW_VOLUME_ID" \
        --instance-id "$INSTANCE_ID" \
        --device "$DEVICE"

    echo "Volume attached successfully."

    # Optionally delete old volume (commented out for safety)
    # echo "Deleting old volume: $VOLUME_ID"
    # aws ec2 delete-volume --volume-id "$VOLUME_ID"

done <<< "$ATTACHMENTS"

# Start the instance
echo ""
echo "Starting instance..."
aws ec2 start-instances --instance-ids "$INSTANCE_ID"
echo "Instance started. Waiting for it to be running..."
aws ec2 wait instance-running --instance-ids "$INSTANCE_ID"

echo ""
echo "Restore completed successfully!"
echo "Instance $INSTANCE_ID has been restored from snapshot."
