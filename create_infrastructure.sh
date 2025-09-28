#!/bin/bash

REGION="us-east-2"

VPC_ID=$(aws ec2 create-vpc --cidr-block 10.0.0.0/16 --region $REGION --query "Vpc.VpcId" --output text)
echo "Created VPC: $VPC_ID"
echo $VPC_ID > vpc_id.txt

SUBNET_ID_1=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.0.1.0/24 --availability-zone ${REGION}a --region $REGION --query "Subnet.SubnetId" --output text)
SUBNET_ID_2=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.0.2.0/24 --availability-zone ${REGION}b --region $REGION --query "Subnet.SubnetId" --output text)
echo "Created Subnets: $SUBNET_ID_1, $SUBNET_ID_2"

aws ec2 modify-subnet-attribute --subnet-id $SUBNET_ID_1 --map-public-ip-on-launch --region $REGION
aws ec2 modify-subnet-attribute --subnet-id $SUBNET_ID_2 --map-public-ip-on-launch --region $REGION

IGW_ID=$(aws ec2 create-internet-gateway --region $REGION --query "InternetGateway.InternetGatewayId" --output text)
aws ec2 attach-internet-gateway --vpc-id $VPC_ID --internet-gateway-id $IGW_ID --region $REGION
echo "Created and attached Internet Gateway: $IGW_ID"

RTB_ID=$(aws ec2 create-route-table --vpc-id $VPC_ID --region $REGION --query "RouteTable.RouteTableId" --output text)
aws ec2 create-route --route-table-id $RTB_ID --destination-cidr-block 0.0.0.0/0 --gateway-id $IGW_ID --region $REGION
aws ec2 associate-route-table --subnet-id $SUBNET_ID_1 --route-table-id $RTB_ID --region $REGION
aws ec2 associate-route-table --subnet-id $SUBNET_ID_2 --route-table-id $RTB_ID --region $REGION
echo "Created and associated Route Table: $RTB_ID"

aws ec2 create-key-pair --key-name my-key-pair --key-type 'ed25519' --query 'KeyMaterial' --output text > my-key-pair.pem
chmod 400 my-key-pair.pem
echo "Created SSH Key Pair 'my-key-pair'"

MY_IP=$(curl -s ifconfig.me)/32
SECURITY_GRP_ID=$(aws ec2 create-security-group --group-name ITMO-444-544-lab-security-group --description "Security group for SSH and HTTP access" --vpc-id $VPC_ID --region $REGION --query "GroupId" --output text)
aws ec2 authorize-security-group-ingress --group-id $SECURITY_GRP_ID --protocol tcp --port 22 --cidr $MY_IP --region $REGION
aws ec2 authorize-security-group-ingress --group-id $SECURITY_GRP_ID --protocol tcp --port 80 --cidr 0.0.0.0/0 --region $REGION
echo "Security Group created and ingress rules applied."

AMI_ID=$(aws ec2 describe-images --owners 099720109477 --region $REGION --filters "Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*" "Name=architecture,Values=x86_64" "Name=virtualization-type,Values=hvm" --query "Images | sort_by(@, &CreationDate) | [-1].ImageId" --output text)
echo "Found AMI ID: $AMI_ID"

INSTANCE_ID=$(aws ec2 run-instances --image-id $AMI_ID --count 1 --instance-type t3.micro --key-name my-key-pair --security-group-ids $SECURITY_GRP_ID --subnet-id $SUBNET_ID_1 --region $REGION --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=ITMO-444-544-Web-Server}]' --output text --query 'Instances[0].InstanceId')
echo "Instance created: $INSTANCE_ID"

aws ec2 wait instance-running --instance-ids $INSTANCE_ID --region $REGION

PUBLIC_IP=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID --region $REGION --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)
echo "Instance is running. Public IP: $PUBLIC_IP"
echo $INSTANCE_ID > instance_id.txt
echo $PUBLIC_IP > instance_ip.txt
