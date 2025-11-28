#!/bin/bash
set -e

# Load configuration and helpers
source config.txt
source cloudwatch_utils.sh

log_to_cw "=== Creating Infrastructure in region $REGION ==="

#-----------------------------
# S3 Bucket (idempotent-ish)
#-----------------------------
aws s3api create-bucket \
  --bucket "$RESUME_BUCKET_NAME" \
  --region "$REGION" \
  --create-bucket-configuration LocationConstraint="$REGION" \
  2>/dev/null || true
log_to_cw "S3 bucket ensured: $RESUME_BUCKET_NAME"

#-----------------------------
# VPC
#-----------------------------
VPC_ID=$(aws ec2 create-vpc \
  --cidr-block "$VPC_CIDR" \
  --region "$REGION" \
  --query "Vpc.VpcId" \
  --output text)
echo "$VPC_ID" > vpc_id.txt
log_to_cw "VPC created: $VPC_ID"

#-----------------------------
# Availability Zones & Subnets
#-----------------------------
AZS=($(aws ec2 describe-availability-zones \
  --region "$REGION" \
  --query 'AvailabilityZones[?State==`available`].ZoneName' \
  --output text))

SUBNET1_AZ="${AZS[0]}"
SUBNET2_AZ="${AZS[1]:-${AZS[0]}}"

SUBNET1=$(aws ec2 create-subnet \
  --vpc-id "$VPC_ID" \
  --cidr-block "$SUBNET_CIDR_1" \
  --availability-zone "$SUBNET1_AZ" \
  --query "Subnet.SubnetId" \
  --output text)

SUBNET2=$(aws ec2 create-subnet \
  --vpc-id "$VPC_ID" \
  --cidr-block "$SUBNET_CIDR_2" \
  --availability-zone "$SUBNET2_AZ" \
  --query "Subnet.SubnetId" \
  --output text)

echo "$SUBNET1" > subnet1_id.txt
echo "$SUBNET2" > subnet2_id.txt
log_to_cw "Subnets created: $SUBNET1 ($SUBNET1_AZ), $SUBNET2 ($SUBNET2_AZ)"

#-----------------------------
# Internet Gateway
#-----------------------------
IGW_ID=$(aws ec2 create-internet-gateway \
  --region "$REGION" \
  --query "InternetGateway.InternetGatewayId" \
  --output text)

aws ec2 attach-internet-gateway \
  --vpc-id "$VPC_ID" \
  --internet-gateway-id "$IGW_ID" \
  --region "$REGION"

echo "$IGW_ID" > igw_id.txt
log_to_cw "Internet Gateway attached: $IGW_ID"

#-----------------------------
# Route Table
#-----------------------------
RTB_ID=$(aws ec2 create-route-table \
  --vpc-id "$VPC_ID" \
  --region "$REGION" \
  --query "RouteTable.RouteTableId" \
  --output text)

aws ec2 create-route \
  --route-table-id "$RTB_ID" \
  --destination-cidr-block 0.0.0.0/0 \
  --gateway-id "$IGW_ID" \
  --region "$REGION"

aws ec2 associate-route-table \
  --route-table-id "$RTB_ID" \
  --subnet-id "$SUBNET1" \
  --region "$REGION"

aws ec2 associate-route-table \
  --route-table-id "$RTB_ID" \
  --subnet-id "$SUBNET2" \
  --region "$REGION"

echo "$RTB_ID" > rtb_id.txt
log_to_cw "Route table created and associated: $RTB_ID"

#-----------------------------
# Security Group (idempotent)
#-----------------------------
MY_IP="$(curl -s ifconfig.me)/32"

EXISTING_SG_ID=$(aws ec2 describe-security-groups \
  --filters "Name=vpc-id,Values=$VPC_ID" "Name=group-name,Values=$SECURITY_GROUP_NAME" \
  --query "SecurityGroups[0].GroupId" \
  --output text \
  --region "$REGION" 2>/dev/null || echo "None")

if [[ "$EXISTING_SG_ID" != "None" && -n "$EXISTING_SG_ID" ]]; then
  SG_ID="$EXISTING_SG_ID"
  log_to_cw "Reusing existing Security Group: $SG_ID"
else
  SG_ID=$(aws ec2 create-security-group \
    --group-name "$SECURITY_GROUP_NAME" \
    --description "$SECURITY_GROUP_DESC" \
    --vpc-id "$VPC_ID" \
    --region "$REGION" \
    --query "GroupId" \
    --output text)

  aws ec2 authorize-security-group-ingress \
    --group-id "$SG_ID" \
    --protocol tcp \
    --port 22 \
    --cidr "$MY_IP" \
    --region "$REGION" 2>/dev/null || true

  aws ec2 authorize-security-group-ingress \
    --group-id "$SG_ID" \
    --protocol tcp \
    --port 80 \
    --cidr 0.0.0.0/0 \
    --region "$REGION" 2>/dev/null || true

  log_to_cw "Security Group created: $SG_ID"
fi

echo "$SG_ID" > sg_id.txt

#-----------------------------
# Key Pair (idempotent)
#-----------------------------
if [[ -f "$KEY_FILE" ]]; then
  log_to_cw "Key file $KEY_FILE already exists; skipping key pair creation."
else
  aws ec2 create-key-pair \
    --key-name "$KEY_NAME" \
    --key-type "$KEY_TYPE" \
    --region "$REGION" \
    --query "KeyMaterial" \
    --output text > "$KEY_FILE"
  chmod 400 "$KEY_FILE"
  log_to_cw "Key pair created: $KEY_NAME"
fi

#-----------------------------
# AMI (latest Ubuntu)
#-----------------------------
AMI_ID=$(aws ec2 describe-images \
  --owners "$UBUNTU_OWNER" \
  --filters "Name=name,Values=$UBUNTU_FILTER" \
  --region "$REGION" \
  --query "Images|sort_by(@,&CreationDate)|[-1].ImageId" \
  --output text)

log_to_cw "Using AMI: $AMI_ID"

#-----------------------------
# EC2 User Data - clone repo & start app
#-----------------------------
USER_DATA=$(cat <<EOT
#!/bin/bash
set -e

apt update -y
apt install -y python3-pip git

echo "export RESUME_BUCKET_NAME=$RESUME_BUCKET_NAME" >> /etc/profile.d/resume_app.sh
export RESUME_BUCKET_NAME=$RESUME_BUCKET_NAME

cd /home/ubuntu

if [[ ! -d ITMO_444_Fall2025 ]]; then
  git clone https://github.com/ahussain33/ITMO_444_Fall2025.git
fi

cd ITMO_444_Fall2025/FINAL_PROJECT/api

pip3 install -r requirements.txt gunicorn

nohup gunicorn --bind 0.0.0.0:80 app:app >/var/log/gunicorn.log 2>&1 &
EOT
)

#-----------------------------
# Launch EC2 Instance (no instance profile)
#-----------------------------
INSTANCE_ID=$(aws ec2 run-instances \
  --image-id "$AMI_ID" \
  --count 1 \
  --instance-type "$INSTANCE_TYPE" \
  --key-name "$KEY_NAME" \
  --security-group-ids "$SG_ID" \
  --subnet-id "$SUBNET1" \
  --associate-public-ip-address \
  --user-data "$USER_DATA" \
  --region "$REGION" \
  --query "Instances[0].InstanceId" \
  --output text)

aws ec2 wait instance-running \
  --instance-ids "$INSTANCE_ID" \
  --region "$REGION"

PUBLIC_IP=$(aws ec2 describe-instances \
  --instance-ids "$INSTANCE_ID" \
  --region "$REGION" \
  --query "Reservations[0].Instances[0].PublicIpAddress" \
  --output text)

echo "$INSTANCE_ID" > instance_id.txt
echo "$PUBLIC_IP" > instance_ip.txt

log_to_cw "EC2 instance created: $INSTANCE_ID ($PUBLIC_IP)"
send_cw_metric 1
