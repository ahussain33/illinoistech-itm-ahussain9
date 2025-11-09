#!/bin/bash

source config.txt
source cloudwatch_utils.sh

log_to_cw "Scaling infrastructure: launching 1 extra instance"
AMI_ID=$(aws ec2 describe-images --owners "$UBUNTU_OWNER" \
--filters "Name=name,Values=$UBUNTU_FILTER" \
--region "$REGION" \
--query "Images | sort_by(@, &CreationDate) | [-1].ImageId" --output text)
SUBNET1=$(aws ec2 describe-subnets --filters "Name=cidr-block,Values=$SUBNET_CIDR_1" \
--query "Subnets[0].SubnetId" --output text --region "$REGION")
SG_ID=$(aws ec2 describe-security-groups --filters "Name=group-name,Values=$SECURITY_GROUP_NAME" \
--query "SecurityGroups[0].GroupId" --output text --region "$REGION")
INSTANCE_ID=$(aws ec2 run-instances --image-id "$AMI_ID" --count 1 \
--instance-type "$INSTANCE_TYPE" --key-name "$KEY_NAME" \
--security-group-ids "$SG_ID" --subnet-id "$SUBNET1" --associate-public-ip-address \
--region "$REGION" --query "Instances[0].InstanceId" --output text)
aws ec2 wait instance-running --instance-ids "$INSTANCE_ID" --region "$REGION"
PUBLIC_IP=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" \
--query "Reservations[0].Instances[0].PublicIpAddress" --output text --region "$REGION")
echo "$INSTANCE_ID" >> instance_id.txt
echo "$PUBLIC_IP" >> instance_ip.txt
log_to_cw "Scaled: new instance $INSTANCE_ID ($PUBLIC_IP)"
send_cw_metric 1
