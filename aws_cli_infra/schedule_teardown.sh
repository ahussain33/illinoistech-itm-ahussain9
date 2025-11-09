#!/bin/bash

source config.txt
source cloudwatch_utils.sh
log_to_cw "Scheduling auto teardown in $AUTO_TEARDOWN_HOURS hours"
CRON_CMD="bash /vagrant/destroy_infrastructure.sh >> /vagrant/teardown.log 2>&1"
CRON_TIME=$(date -d "+$AUTO_TEARDOWN_HOURS hours" '+%M %H %d %m *')
(crontab -l 2>/dev/null; echo "$CRON_TIME $CRON_CMD") | crontab -
log_to_cw "Auto teardown scheduled at $(date -d "+$AUTO_TEARDOWN_HOURS hours")"
