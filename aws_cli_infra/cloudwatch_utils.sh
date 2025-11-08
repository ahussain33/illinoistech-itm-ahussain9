#!/bin/bash

cat > cloudwatch_utils.sh << 'EOF'

log_to_cw() {
  MESSAGE="$1"
  TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
  echo "[$TIMESTAMP] $MESSAGE"
  
  aws logs create-log-group --log-group-name "$CW_LOG_GROUP" \
    --region "$REGION" 2>/dev/null || true
  
  aws logs create-log-stream --log-group-name "$CW_LOG_GROUP" \
    --log-stream-name "$CW_LOG_STREAM" \
    --region "$REGION" 2>/dev/null || true
  
  aws logs put-log-events --log-group-name "$CW_LOG_GROUP" \
    --log-stream-name "$CW_LOG_STREAM" \
    --log-events "timestamp=$(($(date +%s%N)/1000000)),message=$MESSAGE" \
    --region "$REGION" 2>/dev/null || true
}

send_cw_metric() {
  VALUE="$1"
  aws cloudwatch put-metric-data --namespace "$CW_METRIC_NAMESPACE" \
    --metric-name "$CW_METRIC_NAME" \
    --value "$VALUE" --region "$REGION"
}

# Only run main code if executed directly (not sourced)
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  # Load configuration
  if [ -f config.txt ]; then
    source config.txt
  else
    echo "Error: config.txt not found!"
    exit 1
  fi
  
  # Example usage when executed directly
  log_to_cw "Script started"
  send_cw_metric 1
  
  echo "CloudWatch logging functions are ready to use"
fi
EOF

chmod +x cloudwatch_utils.sh
