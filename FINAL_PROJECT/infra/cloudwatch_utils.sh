#!/bin/bash

log_to_cw() {
    local MESSAGE="$1"
    local TIMESTAMP
    TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")

    # Always echo locally so you can see logs even if CloudWatch fails
    echo "[$TIMESTAMP] $MESSAGE"

    # Best-effort CloudWatch logging; ignore any errors
    aws logs create-log-group \
        --log-group-name "$CW_LOG_GROUP" \
        --region "$REGION" 2>/dev/null || true

    aws logs create-log-stream \
        --log-group-name "$CW_LOG_GROUP" \
        --log-stream-name "$CW_LOG_STREAM" \
        --region "$REGION" 2>/dev/null || true

    aws logs put-log-events \
        --log-group-name "$CW_LOG_GROUP" \
        --log-stream-name "$CW_LOG_STREAM" \
        --log-events "timestamp=$(($(date +%s%N)/1000000)),message=$MESSAGE" \
        --region "$REGION" 2>/dev/null || true
}

send_cw_metric() {
    local VALUE="$1"

    aws cloudwatch put-metric-data \
        --namespace "$CW_METRIC_NAMESPACE" \
        --metric-name "$CW_METRIC_NAME" \
        --value "$VALUE" \
        --region "$REGION" 2>/dev/null || true
}
