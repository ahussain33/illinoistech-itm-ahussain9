#!/bin/bash

source config.txt
source cloudwatch_utils.sh
log_to_cw "Destroying infrastructure..."

while read INSTANCE_ID; do
aws ec2 terminate-instances --instance-ids "$INSTANCE_ID" --region "$REGION"
aws ec2 wait instance-terminated --instance-ids "$INSTANCE_ID" --region "$REGION"
done < instance_id.txt

aws ec2 delete-key-pair --key-name "$KEY_NAME" --region "$REGION"

SG_ID=$(aws ec2 describe-security-groups --filters "Name=group-name,Values=$SECURITY_GROUP_NAME" \
--query "SecurityGroups[0].GroupId" --output text --region "$REGION")
aws ec2 delete-security-group --group-id "$SG_ID" --region "$REGION"

VPC_ID=$(cat vpc_id.txt)
aws ec2 delete-vpc --vpc-id "$VPC_ID" --region "$REGION"

rm -f instance_id.txt instance_ip.txt vpc_id.txt
log_to_cw "Infrastructure destroyed successfully"
send_cw_metric 1
