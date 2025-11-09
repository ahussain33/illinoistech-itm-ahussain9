#!/bin/bash

source config.txt
source cloudwatch_utils.sh

TOPIC_ARN=$(aws sns create-topic --name "$SNS_TOPIC_NAME" --region "$REGION" \
--query "TopicArn" --output text)

aws sns subscribe --topic-arn "$TOPIC_ARN" --protocol email \
--notification-endpoint "$ALARM_EMAIL" \
--region "$REGION"
log_to_cw "SNS Topic created: $TOPIC_ARN"

aws cloudwatch put-metric-alarm --alarm-name "$ALARM_NAME" --metric-name "$CW_METRIC_NAME" \
--namespace "$CW_METRIC_NAMESPACE" --statistic Sum --period 300 --threshold 0 \
--comparison-operator LessThanThreshold \
--evaluation-periods 1 --alarm-actions "$TOPIC_ARN" --region "$REGION"
log_to_cw "CloudWatch Alarm created: $ALARM_NAME"
send_cw_metric 1
