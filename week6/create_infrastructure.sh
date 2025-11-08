#!/bin/bash

REGION="us-east-2"

VPC_ID=$(aws ec2 create-vpc --cidr-block 10.0.0.0/16 --region $REGION --query "Vpc.VpcId" --output text)
echo "Created VPC: $VPC_ID"
VPC_ID="vpc-033b3d6d9077ec539"

SUBNET_ID_1=$(aws ec2 create-subnet --vpc-id $VPC_ID \
--cidr-block 10.0.1.0/24 \
--availability-zone ${REGION}a \
--region $REGION \
--query "Subnet.SubnetId" \
--output text)
SUBNET_ID_2=$(aws ec2 create-subnet --vpc-id $VPC_ID \
--cidr-block 10.0.2.0/24 \
--availability-zone ${REGION}b \
--region $REGION \
--query "Subnet.SubnetId" \
--output text)
echo "Created Subnets: $SUBNET_ID_1, $SUBNET_ID_2"

SUBNET_ID_1="subnet-0319d7d2e88f6626d"
SUBNET_ID_2="subnet-0058e0c4c43b56138"

IGW_ID=$(aws ec2 create-internet-gateway --region $REGION \
--query "InternetGateway.InternetGatewayId" \
--output text)
aws ec2 attach-internet-gateway --vpc-id $VPC_ID \
--internet-gateway-id $IGW_ID \
--region $REGION

IGW_ID="igw-07405327b9a8f089b"

RTB_ID=$(aws ec2 create-route-table --vpc-id $VPC_ID \
--region $REGION \
--query "RouteTable.RouteTableId" \
--output text)
aws ec2 create-route --route-table-id $RTB_ID \
--destination-cidr-block 0.0.0.0/0 \
--gateway-id $IGW_ID \
--region $REGION
aws ec2 associate-route-table --subnet-id $SUBNET_ID_1 \
--route-table-id $RTB_ID \
--region $REGION
aws ec2 associate-route-table --subnet-id $SUBNET_ID_2 \
--route-table-id $RTB_ID \
--region $REGION
echo "Created and associated Route Table: $RTB_ID"

RTB_ID="rtb-00b437bf899f6a22d"

MY_IP=$(curl -s ifconfig.me)/32

aws ec2 create-security-group --group-name itmo-444_v2 \
  --description "Security group for SSH and HTTP access" --region $REGION

aws ec2 authorize-security-group-ingress --group-name itmo-444_v2 \
  --protocol tcp --port 22 --cidr $MY_IP --region $REGION 

aws ec2 authorize-security-group-ingress --group-name itmo-444_v2 \
  --protocol tcp --port 80 --cidr 0.0.0.0/0 --region $REGION

AMI_ID=$(aws ec2 describe-images --owners 099720109477 \
--region $REGION \
--filters "Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*" \
"Name=architecture,Values=x86_64" \
"Name=virtualization-type,Values=hvm" \
--query "Images | sort_by(@, &CreationDate) | [-1].ImageId" \
--output text)

AMI_ID="ami-0c5ddb3560e768732"

SECURITY_GRP_ID=$(aws ec2 describe-security-groups --group-names itmo-444_v2 \
  --region $REGION \
  --query "SecurityGroups[0].GroupId" \
  --output text)
  
INSTANCE_ID=$(aws ec2 run-instances \
--image-id $AMI_ID \
--count 1 \
--instance-type t3.micro \
--key-name my-key-pair \
--security-group-ids $SECURITY_GRP_ID \
--region $REGION \
--tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=ITMO-444-544-Web-Server}]' \
--output text \
--query 'Instances[0].InstanceId')
echo "Instance created: $INSTANCE_ID"

INSTANCE_ID="i-08508ec730c064e1a"
aws ec2 wait instance-running --instance-ids $INSTANCE_ID --region $REGION

PUBLIC_IP=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID \
--region $REGION --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)
echo "Instance is running. Public IP: $PUBLIC_IP"
echo $INSTANCE_ID > instance_id.txt
echo $PUBLIC_IP > instance_ip.txt

PUBLIC_IP="3.150.109.5"


