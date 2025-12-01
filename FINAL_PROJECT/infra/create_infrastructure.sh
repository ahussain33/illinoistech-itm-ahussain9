#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

source config.txt

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

log "Checking AWS identity..."
aws sts get-caller-identity >/dev/null
log "AWS identity verified."


AZ=$(aws ec2 describe-availability-zones \
  --region "$REGION" \
  --query 'AvailabilityZones[0].ZoneName' \
  --output text)

log "Using region: $REGION, AZ: $AZ"

log "Creating VPC..."
VPC_ID=$(aws ec2 create-vpc \
  --cidr-block "$VPC_CIDR" \
  --tag-specifications "ResourceType=vpc,Tags=[{Key=Name,Value=ResumeParserVPC}]" \
  --region "$REGION" \
  --query "Vpc.VpcId" \
  --output text)

log "VPC created: $VPC_ID"
echo "$VPC_ID" > vpc_id.txt

# Enable DNS hostnames (nice for SSH)
aws ec2 modify-vpc-attribute \
  --vpc-id "$VPC_ID" \
  --enable-dns-hostnames "{\"Value\":true}" \
  --region "$REGION"

log "Creating Subnet 1..."
SUBNET1_ID=$(aws ec2 create-subnet \
  --vpc-id "$VPC_ID" \
  --cidr-block "$SUBNET_CIDR_1" \
  --availability-zone "$AZ" \
  --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=ResumeSubnet1}]" \
  --region "$REGION" \
  --query "Subnet.SubnetId" \
  --output text)

log "Subnet 1: $SUBNET1_ID"
echo "$SUBNET1_ID" > subnet1_id.txt

log "Creating Subnet 2..."
SUBNET2_ID=$(aws ec2 create-subnet \
  --vpc-id "$VPC_ID" \
  --cidr-block "$SUBNET_CIDR_2" \
  --availability-zone "$AZ" \
  --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=ResumeSubnet2}]" \
  --region "$REGION" \
  --query "Subnet.SubnetId" \
  --output text)

log "Subnet 2: $SUBNET2_ID"
echo "$SUBNET2_ID" > subnet2_id.txt

log "Creating and attaching Internet Gateway..."
IGW_ID=$(aws ec2 create-internet-gateway \
  --region "$REGION" \
  --tag-specifications "ResourceType=internet-gateway,Tags=[{Key=Name,Value=ResumeIGW}]" \
  --query "InternetGateway.InternetGatewayId" \
  --output text)

aws ec2 attach-internet-gateway \
  --vpc-id "$VPC_ID" \
  --internet-gateway-id "$IGW_ID" \
  --region "$REGION"

log "IGW attached: $IGW_ID"
echo "$IGW_ID" > igw_id.txt

log "Creating route table..."
RTB_ID=$(aws ec2 create-route-table \
  --vpc-id "$VPC_ID" \
  --region "$REGION" \
  --tag-specifications "ResourceType=route-table,Tags=[{Key=Name,Value=ResumeRouteTable}]" \
  --query "RouteTable.RouteTableId" \
  --output text)

log "Route table: $RTB_ID"
echo "$RTB_ID" > rtb_id.txt

aws ec2 create-route \
  --route-table-id "$RTB_ID" \
  --destination-cidr-block 0.0.0.0/0 \
  --gateway-id "$IGW_ID" \
  --region "$REGION" >/dev/null

aws ec2 associate-route-table \
  --route-table-id "$RTB_ID" \
  --subnet-id "$SUBNET1_ID" \
  --region "$REGION" >/dev/null

aws ec2 associate-route-table \
  --route-table-id "$RTB_ID" \
  --subnet-id "$SUBNET2_ID" \
  --region "$REGION" >/dev/null

log "Route table associated with both subnets."

log "Creating security group..."

MY_IP="$(curl -s https://ifconfig.me)/32"

SG_ID=$(aws ec2 create-security-group \
  --group-name "$SECURITY_GROUP_NAME" \
  --description "$SECURITY_GROUP_DESC" \
  --vpc-id "$VPC_ID" \
  --region "$REGION" \
  --query "GroupId" \
  --output text)

log "Security group created: $SG_ID"
echo "$SG_ID" > sg_id.txt

# Allow SSH from your IP
aws ec2 authorize-security-group-ingress \
  --group-id "$SG_ID" \
  --protocol tcp \
  --port 22 \
  --cidr "$MY_IP" \
  --region "$REGION" >/dev/null

# Allow HTTP from anywhere
aws ec2 authorize-security-group-ingress \
  --group-id "$SG_ID" \
  --protocol tcp \
  --port 80 \
  --cidr 0.0.0.0/0 \
  --region "$REGION" >/dev/null

log "Ingress rules: 22 from $MY_IP, 80 from 0.0.0.0/0"

log "Ensuring S3 bucket: $RESUME_BUCKET_NAME"

if aws s3api head-bucket --bucket "$RESUME_BUCKET_NAME" 2>/dev/null; then
  log "S3 bucket already exists."
else
  aws s3api create-bucket \
    --bucket "$RESUME_BUCKET_NAME" \
    --region "$REGION" \
    --create-bucket-configuration LocationConstraint="$REGION"
  log "S3 bucket created."
fi

log "Looking up Ubuntu AMI..."
AMI_ID=$(aws ec2 describe-images \
  --owners "$UBUNTU_OWNER" \
  --filters "Name=name,Values=$UBUNTU_FILTER" "Name=state,Values=available" \
  --region "$REGION" \
  --query 'Images | sort_by(@, &CreationDate)[-1].ImageId' \
  --output text)

log "Using AMI: $AMI_ID"
echo "$AMI_ID" > ami_id.txt

log "Launching EC2 instance..."

INSTANCE_ID=$(aws ec2 run-instances \
  --image-id "$AMI_ID" \
  --count 1 \
  --instance-type "$INSTANCE_TYPE" \
  --key-name "$KEY_NAME" \
  --security-group-ids "$SG_ID" \
  --subnet-id "$SUBNET1_ID" \
  --associate-public-ip-address \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$EC2_NAME}]" \
  --region "$REGION" \
  --query "Instances[0].InstanceId" \
  --output text)

log "Instance launched: $INSTANCE_ID"
echo "$INSTANCE_ID" > instance_id.txt

log "Waiting for instance to be running..."
aws ec2 wait instance-running \
  --instance-ids "$INSTANCE_ID" \
  --region "$REGION"

log "Instance is running."

PUBLIC_IP=$(aws ec2 describe-instances \
  --instance-ids "$INSTANCE_ID" \
  --region "$REGION" \
  --query "Reservations[0].Instances[0].PublicIpAddress" \
  --output text)

echo "$PUBLIC_IP" > public_ip.txt

echo "$INSTANCE_ID" > instance_id.txt
echo "$PUBLIC_IP" > instance_ip.txt

log "Instance public IP: $PUBLIC_IP"

log "Infrastructure creation complete."
