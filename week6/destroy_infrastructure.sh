#!/bin/bash
# Set region
REGION="us-east-2"
# Step 1: Get VPC ID
VPC_ID=$(cat vpc_id.txt)
if [ -z "$VPC_ID" ]; then
echo "VPC ID not found. Exiting."
exit 1
fi
# Step 3: Terminate the instance
INSTANCE_ID=$(cat instance_id.txt)
echo "Terminating instance $INSTANCE_ID..."
aws ec2 terminate-instances --instance-ids $INSTANCE_ID --region $REGION
aws ec2 wait instance-terminated --instance-ids $INSTANCE_ID --region $REGION
echo "Instance terminated."
# Step 2: Delete Auto Scaling Group
echo "Deleting Auto Scaling Group..."
aws autoscaling delete-auto-scaling-group \
--auto-scaling-group-name MyNGINXAutoScalingGroup \
--region $REGION \
--force-delete
echo "Auto Scaling Group deleted."
# Step 3: Delete Load Balancer
echo "Deleting Load Balancer..."

aws elb delete-load-balancer \
--load-balancer-name MyNGINXLoadBalancer \
--region $REGION
echo "Load Balancer deleted."
# Step 4: Delete Launch Template
echo "Deleting Launch Template..."
aws ec2 delete-launch-template --launch-template-name MyNGINXLaunchTemplate --region $REGION
echo "Launch Template deleted."
# Step 5: Delete Security Group
echo "Deleting Security Group..."
SECURITY_GROUP_ID=$(aws ec2 describe-security-groups --group-names ITMO-444-544-lab-security-group \
--region $REGION \
--query "SecurityGroups[0].GroupId" \
--output text)
aws ec2 delete-security-group --group-id $SECURITY_GROUP_ID --region $REGION
echo "Security Group deleted."
# Step 6: Delete Subnets
echo "Deleting Subnets..."
SUBNETS=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" --region $REGION for SUBNET in $SUBNETS; do
aws ec2 delete-subnet --subnet-id $SUBNET --region $REGION
echo "Deleted Subnet: $SUBNET"
done
--query "Subn
# Step 7: Delete VPC
echo "Deleting VPC..."
aws ec2 delete-vpc --vpc-id $VPC_ID --region $REGION
echo "VPC deleted."
# Step 8: Delete Internet Gateway
echo "Deleting Internet Gateway..."
IGW_ID=$(aws ec2 describe-internet-gateways --filters "Name=attachment.vpc-id,Values=$VPC_ID" --region $
aws ec2 detach-internet-gateway --internet-gateway-id $IGW_ID --vpc-id $VPC_ID --region $REGION
aws ec2 delete-internet-gateway --internet-gateway-id $IGW_ID --region $REGION
echo "Internet Gateway deleted."
# Step 9: Delete Key Pair
echo "Deleting Key Pair..."
aws ec2 delete-key-pair --key-name my-key-pair --region $REGION
echo "Key Pair deleted."
# Step 10: Clean up any leftover Elastic IPs (optional)
EIP_ALLOC_IDS=$(aws ec2 describe-addresses --query "Addresses[].[AllocationId]" --output text --region $
for EIP in $EIP_ALLOC_IDS; do
aws ec2 release-address --allocation-id $EIP --region $REGION
echo "Released Elastic IP with Allocation ID: $EIP"
done
# Step 11: Clean up any leftover AMIs (optional)

AMI_ID=$(cat ami_id.txt)
if [ -n "$AMI_ID" ]; then
echo "Deregistering AMI..."
aws ec2 deregister-image --image-id $AMI_ID --region $REGION
echo "AMI deregistered."
fi
# Final cleanup: Remove the'instance_id.txt'
,
'instance_ip.txt'
rm -f instance_id.txt instance_ip.txt vpc_id.txt ami_id.txt
,
echo "Infrastructure destroyed successfully."
