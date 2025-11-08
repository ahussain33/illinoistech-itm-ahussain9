#!/bin/bash

REGION="us-east-2"
INSTANCE_ID=$(cat instance_id.txt)
AMI_ID=$(aws ec2 create-image --instance-id $INSTANCE_ID \
--name "MyCustomNGINX-AMI" \
--region $REGION \
--query "ImageId" \
--output text)
echo "Created AMI: $AMI_ID"

AMI_ID="ami-0c11963c0be6e8ea8"
echo "Stopping instance $INSTANCE_ID..."
aws ec2 stop-instances --instance-ids $INSTANCE_ID --region $REGION
aws ec2 wait instance-stopped --instance-ids $INSTANCE_ID --region $REGION
echo "Instance stopped."
SECURITY_GRP_ID=$(aws ec2 describe-security-groups --group-names itmo-444_v2 \
  --query "SecurityGroups[0].GroupId" --output text)

aws ec2 create-launch-template --launch-template-name "MyNGINXLaunchTemplate" \
  --version-description "v1" \
  --launch-template-data "{\"ImageId\":\"$AMI_ID\",\"InstanceType\":\"t3.micro\",\"KeyName\":\"my-key-pair\",\"SecurityGroupIds\":[\"$SECURITY_GRP_ID\"]}" \
  --region $REGION \
  --output json
echo "Launch Template created."
VPC_ZONE_IDENTIFIER=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" \
  --region $REGION \
  --query "Subnets[].SubnetId" \
  --output text)

aws autoscaling create-auto-scaling-group \
  --auto-scaling-group-name MyNGINXAutoScalingGroup \
  --launch-template "LaunchTemplateName=MyNGINXLaunchTemplate,Version=1" \
  --min-size 2 --max-size 5 --desired-capacity 2 \
  --vpc-zone-identifier "$VPC_ZONE_IDENTIFIER" \
  --region $REGION --output json

echo "Auto Scaling Group created."

echo "Subnet 1: $SUBNET_ID_1"
echo "Subnet 2: $SUBNET_ID_2"

#vpc for some reason was listed as a different one for one of the subnets, but hard coded it for now
VPC_ID="vpc-0ccc1d20b201b96fa"

SUBNET_IDS=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" \
  --region $REGION \
  --query "Subnets[].SubnetId" \
  --output text)

echo "Subnets: $SUBNET_IDS"

aws elb create-load-balancer \
  --load-balancer-name MyNGINXLoadBalancer \
  --listeners "Protocol=HTTP,LoadBalancerPort=80,InstanceProtocol=HTTP,InstancePort=80" \
  --subnets $SUBNET_IDS \
  --security-groups $SECURITY_GRP_ID \
  --region $REGION --output json




  
