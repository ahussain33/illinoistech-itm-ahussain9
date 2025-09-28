#!/bin/bash
# Set region
REGION="us-east-2"
INSTANCE_ID=$(cat instance_id.txt)
# Step 1: Create AMI (Amazon Machine Image) from the instance
AMI_ID=$(aws ec2 create-image --instance-id $INSTANCE_ID \
--name "MyCustomNGINX-AMI" \
--region $REGION \
--query "ImageId" \
--output text)
echo "Created AMI: $AMI_ID"
# Step 2: Stop the instance
echo "Stopping instance $INSTANCE_ID..."
aws ec2 stop-instances --instance-ids $INSTANCE_ID --region $REGION --no-reboot
aws ec2 wait instance-stopped --instance-ids $INSTANCE_ID --region $REGION
echo "Instance stopped."
# Step 2: Create Launch Template using the custom AMI
SECURITY_GRP_ID =$(aws ec2 describe-security-groups --group-names ITMO-444-544-lab-security-group \
--query "SecurityGroups[0].GroupId" --output text)
aws ec2 create-launch-template --launch-template-name "MyNGINXLaunchTemplate" \
--version-description "v1" --image-id $AMI_ID \
--output json
echo "Launch Template created."
# Step 3: Create Auto Scaling Group
VPC_ZONE_IDENTIFIER=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" \
--query "Subnets[].SubnetId" \
--output text)
aws autoscaling create-auto-scaling-group \
--auto-scaling-group-name MyNGINXAutoScalingGroup \
--launch-template "LaunchTemplateName=MyNGINXLaunchTemplate,Version=1" \
--min-size 2 --max-size 5 --desired-capacity 2 \
--vpc-zone-identifier $VPC_ZONE_IDENTIFIER \
--region $REGION --output json
echo "Auto Scaling Group created."
# Step 4: Create Load Balancer
SUBNET_ID=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" \
--query "Subnets[].SubnetId" \
--output text)
aws elb create-load-balancer \
--load-balancer-name MyNGINXLoadBalancer \
--listeners "Protocol=HTTP,LoadBalancerPort=80,InstanceProtocol=HTTP,InstancePort=80" \
--subnets SUBNET_ID \
--security-groups $SECURITY_GRP_ID \
--region $REGION --output json
