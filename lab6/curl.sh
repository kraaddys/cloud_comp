#!/bin/bash
set -e

if [ $# < 3 ]; then
    echo "Usage: $0 <alb_dns_name> <threads> <seconds>"
    echo "Example: $0 lab6-alb-1847776352.eu-central-1.elb.amazonaws.com 20 60"
    exit 1
fi

ALB_DNS="$1"
THREADS="$2"
SECONDS="$3"

TARGET="http://$ALB_DNS/load?seconds=$SECONDS"

echo "========================================="
echo " Starting load against: $TARGET"
echo " Threads: $THREADS"
echo " Duration: $SECONDS seconds"
echo "========================================="

END_TIME=$(( $(date +%s) + SECONDS ))

for ((i=1; i<=THREADS; i++)); do
    (
        while [ "$(date +%s)" -lt "$END_TIME" ]; do
            curl -s "$TARGET" > /dev/null || true
        done
    ) &
done

wait
echo "Load finished."
