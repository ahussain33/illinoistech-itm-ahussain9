#!/bin/bash
source config.txt
source cloudwatch_utils.sh
log_to_cw "=== Creating Infrastructure ==="

VPC_ID=$(aws ec2 create-vpc --cidr-block "$VPC_CIDR" --region "$REGION" \
--query "Vpc.VpcId" --output text)
echo "$VPC_ID" > vpc_id.txt
log_to_cw "VPC created: $VPC_ID"

SUBNET1=$(aws ec2 create-subnet --vpc-id "$VPC_ID" --cidr-block "$SUBNET_CIDR_1" \
--availability-zone "${REGION}a" --query "Subnet.SubnetId" --output text)
SUBNET2=$(aws ec2 create-subnet --vpc-id "$VPC_ID" --cidr-block "$SUBNET_CIDR_2" \
--availability-zone "${REGION}b" --query "Subnet.SubnetId" --output text)
log_to_cw "Subnets created: $SUBNET1, $SUBNET2"

IGW_ID=$(aws ec2 create-internet-gateway --region "$REGION" \
--query "InternetGateway.InternetGatewayId" --output text)
aws ec2 attach-internet-gateway --vpc-id "$VPC_ID" --internet-gateway-id "$IGW_ID" \
--region "$REGION"
log_to_cw "Internet Gateway attached: $IGW_ID"

RTB_ID=$(aws ec2 create-route-table --vpc-id "$VPC_ID" --region "$REGION" \
--query "RouteTable.RouteTableId" --output text)
aws ec2 create-route --route-table-id "$RTB_ID" --destination-cidr-block 0.0.0.0/0 \
--gateway-id "$IGW_ID" --region "$REGION"
aws ec2 associate-route-table --route-table-id "$RTB_ID" --subnet-id "$SUBNET1" \
--region "$REGION"
aws ec2 associate-route-table --route-table-id "$RTB_ID" --subnet-id "$SUBNET2" \
--region "$REGION"

MY_IP=$(curl -s ifconfig.me)/32
SG_ID=$(aws ec2 create-security-group --group-name "$SECURITY_GROUP_NAME" \
--description "$SECURITY_GROUP_DESC" --vpc-id "$VPC_ID" --region "$REGION" \
--query "GroupId" --output text)
aws ec2 authorize-security-group-ingress --group-id "$SG_ID" --protocol tcp --port 22 \
--cidr "$MY_IP" --region "$REGION"
aws ec2 authorize-security-group-ingress --group-id "$SG_ID" --protocol tcp --port 80 \
--cidr 0.0.0.0/0 --region "$REGION"
log_to_cw "Security Group created: $SG_ID"

aws ec2 create-key-pair --key-name "$KEY_NAME" --key-type "$KEY_TYPE" --region "$REGION" \
  --query "KeyMaterial" --output text > "$KEY_FILE"
chmod 400 "$KEY_FILE"
echo "Key pair created: $KEY_NAME"

AMI_ID=$(aws ec2 describe-images --owners "$UBUNTU_OWNER" \
--filters "Name=name,Values=$UBUNTU_FILTER" \
--region "$REGION" \
--query "Images | sort_by(@, &CreationDate) | [-1].ImageId" --output text)
