#!/bin/bash

REGION="us-east-2"
VPC_ID=$(cat vpc_id.txt)

if [ -z "$VPC_ID" ]; then
  echo "VPC ID not found. Exiting."
  exit 1
fi

INSTANCE_ID=$(cat instance_id.txt)
echo "Terminating instance $INSTANCE_ID..."
aws ec2 terminate-instances --instance-ids $INSTANCE_ID --region $REGION
aws ec2 wait instance-terminated --instance-ids $INSTANCE_ID --region $REGION
echo "Instance terminated."

echo "Deleting Auto Scaling Group..."
aws autoscaling delete-auto-scaling-group \
  --auto-scaling-group-name MyNGINXAutoScalingGroup \
  --region $REGION \
  --force-delete
echo "Auto Scaling Group deleted."

echo "Deleting Load Balancer..."
aws elb delete-load-balancer \
  --load-balancer-name MyNGINXLoadBalancer \
  --region $REGION
echo "Load Balancer deleted."

echo "Deleting Launch Template..."
aws ec2 delete-launch-template --launch-template-name MyNGINXLaunchTemplate --region $REGION
echo "Launch Template deleted."

echo "Deleting Internet Gateway..."
IGW_ID=$(aws ec2 describe-internet-gateways \
  --filters "Name=attachment.vpc-id,Values=$VPC_ID" \
  --region $REGION \
  --query "InternetGateways[0].InternetGatewayId" \
  --output text)

if [ "$IGW_ID" != "None" ] && [ -n "$IGW_ID" ]; then
  aws ec2 detach-internet-gateway --internet-gateway-id $IGW_ID --vpc-id $VPC_ID --region $REGION
  aws ec2 delete-internet-gateway --internet-gateway-id $IGW_ID --region $REGION
  echo "Internet Gateway deleted."
fi

echo "Deleting Security Group..."
SECURITY_GROUP_ID=$(aws ec2 describe-security-groups \
  --group-names ITMO-444 \
  --region $REGION \
  --query "SecurityGroups[0].GroupId" \
  --output text)
aws ec2 delete-security-group --group-id $SECURITY_GROUP_ID --region $REGION
echo "Security Group deleted."

echo "Deleting Subnets..."
SUBNETS=$(aws ec2 describe-subnets \
  --filters "Name=vpc-id,Values=$VPC_ID" \
  --region $REGION \
  --query "Subnets[].SubnetId" \
  --output text)
for SUBNET in $SUBNETS; do
  aws ec2 delete-subnet --subnet-id $SUBNET --region $REGION
  echo "Deleted Subnet: $SUBNET"
done

echo "Deleting VPC..."
aws ec2 delete-vpc --vpc-id $VPC_ID --region $REGION
echo "VPC deleted."

echo "Deleting Key Pair..."
aws ec2 delete-key-pair --key-name my-key-pair --region $REGION
echo "Key Pair deleted."
