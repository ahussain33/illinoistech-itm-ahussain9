#!/bin/bash

cat > config.txt << 'EOF'
REGION=us-east-2
VPC_CIDR=10.0.0.0/16
SUBNET_CIDR_1=10.0.1.0/24
SUBNET_CIDR_2=10.0.2.0/24
INSTANCE_TYPE=t2.micro
KEY_NAME=my-key-pair
KEY_FILE=my-key-pair.pem
KEY_TYPE=ed25519
SECURITY_GROUP_NAME=itmo-444
SECURITY_GROUP_DESC="SSH & HTTP access"
UBUNTU_OWNER=099720109477
UBUNTU_FILTER=ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*
CW_LOG_GROUP=infra-automation-logs
CW_LOG_STREAM=automation-run
CW_METRIC_NAMESPACE=InfraAutomation
CW_METRIC_NAME=StepsCompleted
SNS_TOPIC_NAME=InfraAutomationAlerts
ALARM_NAME=InfraAutomationFailureAlarm
ALARM_EMAIL=abiha2338@gmail.com
AUTO_TEARDOWN_HOURS=2
EOF

echo "Configuration saved to config.txt"
