#!/bin/bash
set -e

source config.txt
source cloudwatch_utils.sh

log_to_cw "Destroying infrastructure..."

# Terminate EC2 instances
if [[ -f instance_id.txt ]]; then
  while read -r INSTANCE_ID; do
    [[ -z "$INSTANCE_ID" ]] && continue
    log_to_cw "Terminating EC2 instance: $INSTANCE_ID"
    aws ec2 terminate-instances \
      --instance-ids "$INSTANCE_ID" \
      --region "$REGION" || true
  done < instance_id.txt

  IDS=$(tr '\n' ' ' < instance_id.txt)
  aws ec2 wait instance-terminated \
    --instance-ids $IDS \
    --region "$REGION" || true
fi

# Check if bucket exists first
if aws s3api head-bucket --bucket "$RESUME_BUCKET_NAME" 2>/dev/null; then
    log_to_cw "Bucket exists. Deleting all objects..."
    aws s3 rm "s3://$RESUME_BUCKET_NAME" --recursive --region "$REGION"
    log_to_cw "Removing bucket..."
    aws s3api delete-bucket --bucket "$RESUME_BUCKET_NAME" --region "$REGION" 
    log_to_cw "S3 bucket deleted successfully."
else
    log_to_cw "S3 bucket does not exist."
fi

# Detach & delete Internet Gateway
if [[ -f igw_id.txt && -f vpc_id.txt ]]; then
  IGW_ID=$(cat igw_id.txt)
  VPC_ID=$(cat vpc_id.txt)
  log_to_cw "Detaching and deleting IGW: $IGW_ID from VPC: $VPC_ID"

  aws ec2 detach-internet-gateway \
    --internet-gateway-id "$IGW_ID" \
    --vpc-id "$VPC_ID" \
    --region "$REGION" 2>/dev/null || true

  aws ec2 delete-internet-gateway \
    --internet-gateway-id "$IGW_ID" \
    --region "$REGION" 2>/dev/null || true
fi

# Delete Route Table
if [[ -f rtb_id.txt ]]; then
  RTB_ID=$(cat rtb_id.txt)
  log_to_cw "Deleting route table: $RTB_ID"

  ASSOC_IDS=$(aws ec2 describe-route-tables \
    --route-table-ids "$RTB_ID" \
    --region "$REGION" \
    --query 'RouteTables[0].Associations[?Main==`false`].RouteTableAssociationId' \
    --output text 2>/dev/null || echo "")

  for AID in $ASSOC_IDS; do
    aws ec2 disassociate-route-table \
      --association-id "$AID" \
      --region "$REGION" 2>/dev/null || true
  done

  aws ec2 delete-route-table \
    --route-table-id "$RTB_ID" \
    --region "$REGION" 2>/dev/null || true
fi

# Delete Subnets
if [[ -f subnet1_id.txt ]]; then
  SUBNET1=$(cat subnet1_id.txt)
  log_to_cw "Deleting subnet: $SUBNET1"
  aws ec2 delete-subnet \
    --subnet-id "$SUBNET1" \
    --region "$REGION" 2>/dev/null || true
fi

if [[ -f subnet2_id.txt ]]; then
  SUBNET2=$(cat subnet2_id.txt)
  log_to_cw "Deleting subnet: $SUBNET2"
  aws ec2 delete-subnet \
    --subnet-id "$SUBNET2" \
    --region "$REGION" 2>/dev/null || true
fi

# Delete Security Group
if [[ -f sg_id.txt ]]; then
  SG_ID=$(cat sg_id.txt)
else
  SG_ID=$(aws ec2 describe-security-groups \
    --filters "Name=group-name,Values=$SECURITY_GROUP_NAME" \
    --region "$REGION" \
    --query "SecurityGroups[0].GroupId" \
    --output text 2>/dev/null || echo "")
fi

if [[ -n "$SG_ID" && "$SG_ID" != "None" ]]; then
  log_to_cw "Deleting security group: $SG_ID"
  aws ec2 delete-security-group \
    --group-id "$SG_ID" \
    --region "$REGION" 2>/dev/null || true
fi

# Delete VPC
if [[ -f vpc_id.txt ]]; then
  VPC_ID=$(cat vpc_id.txt)
  log_to_cw "Deleting VPC: $VPC_ID"
  aws ec2 delete-vpc \
    --vpc-id "$VPC_ID" \
    --region "$REGION" 2>/dev/null || true
fi

# Delete CloudWatch Log Group
aws logs delete-log-group \
  --log-group-name "$CW_LOG_GROUP" \
  --region "$REGION" 2>/dev/null || true

# Clean up IAM Role / Instance Profile
if [[ -f instance_profile_name.txt ]]; then
  INSTANCE_PROFILE_NAME=$(cat instance_profile_name.txt)
  IAM_ROLE_NAME="ResumeParserRole"
  IAM_POLICY_NAME="ResumeParserS3Policy"

  log_to_cw "Cleaning up IAM resources: $INSTANCE_PROFILE_NAME / $IAM_ROLE_NAME"

  aws iam remove-role-from-instance-profile \
    --instance-profile-name "$INSTANCE_PROFILE_NAME" \
    --role-name "$IAM_ROLE_NAME" \
    2>/dev/null || true

  aws iam delete-instance-profile \
    --instance-profile-name "$INSTANCE_PROFILE_NAME" \
    2>/dev/null || true

  aws iam delete-role-policy \
    --role-name "$IAM_ROLE_NAME" \
    --policy-name "$IAM_POLICY_NAME" \
    2>/dev/null || true

  aws iam delete-role \
    --role-name "$IAM_ROLE_NAME" \
    2>/dev/null || true
fi

rm -f instance_id.txt instance_ip.txt vpc_id.txt sg_id.txt \
      igw_id.txt rtb_id.txt subnet1_id.txt subnet2_id.txt \
      instance_profile_name.txt teardown.log

log_to_cw "Infrastructure destroyed successfully"
send_cw_metric 1
