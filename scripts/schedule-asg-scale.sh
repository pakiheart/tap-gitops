#!/usr/bin/env bash
#
# TODO: Add region support!!!!
# TODO: Assumes region is exported/or in your .aws config

# queries by eks cluster name
for CLUSTER in "$@"; do
    ASG_GROUP=$(aws autoscaling describe-auto-scaling-groups --filters Name=tag-key,Values=eks:cluster-name Name=tag-value,Values=$CLUSTER | jq -r ".AutoScalingGroups[].AutoScalingGroupName")
    
    echo "Adding morning autoscaler for $ASG_GROUP in $CLUSTER eks cluster..."

    aws autoscaling put-scheduled-update-group-action \
    --scheduled-action-name morning-scale-up\
    --recurrence "0 5 * * 1-5" \
    --time-zone "America/Phoenix" \
    --desired-capacity 3 \
    --min-size 3 \
    --max-size 3 \
    --auto-scaling-group-name $ASG_GROUP

    echo "Adding evening autoscaler for $ASG_GROUP in $CLUSTER eks cluster..."

    aws autoscaling put-scheduled-update-group-action \
    --scheduled-action-name evening-scale-down \
    --recurrence "0 17 * * 1-5" \
    --time-zone "America/Phoenix" \
    --desired-capacity 0 \
    --min-size 0 \
    --max-size 0 \
  --auto-scaling-group-name $ASG_GROUP

done
