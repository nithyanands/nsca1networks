#!/usr/bin/env bash
# Three-layer health check for the deployment:
#   1. INFRASTRUCTURE (AWS) - is the instance actually running, is the
#      security group correctly configured
#   2. MIDDLEWARE (server/container) - is SSH reachable, is Docker running,
#      is the container up with the correct restart policy
#   3. APPLICATION - is the app actually serving traffic
#
# Usage: ./health_check.sh
# Requires: terraform (state present), aws cli (configured), ssh key access

set -uo pipefail   # no -e: we want to keep checking even if one check fails

KEY_PATH="$HOME/.ssh/id_rsa"
APP_PORT=8501

PASS=0
WARN=0
FAIL=0

pass() { echo "  [PASS] $1"; PASS=$((PASS+1)); }
warn() { echo "  [WARN] $1"; WARN=$((WARN+1)); }
fail() { echo "  [FAIL] $1"; FAIL=$((FAIL+1)); }

echo "=================================================="
echo " HEALTH CHECK - $(date)"
echo "=================================================="

# ---------- Gather identifiers from Terraform state ----------
INSTANCE_ID=$(terraform output -raw instance_id 2>/dev/null)
PUBLIC_IP=$(terraform output -raw instance_public_ip 2>/dev/null)
SG_ID=$(terraform output -raw security_group_id 2>/dev/null)

if [ -z "$PUBLIC_IP" ]; then
  echo "ERROR: Could not read Terraform outputs. Run this from the folder"
  echo "containing your .tf files, after a successful 'terraform apply'."
  exit 1
fi

echo "Instance ID: $INSTANCE_ID"
echo "Public IP:   $PUBLIC_IP"
echo "Security Group: $SG_ID"
echo ""

# ==================================================
echo "--- LAYER 1: INFRASTRUCTURE (AWS) ---"
# ==================================================

# 1.1 Instance state
STATE=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" \
  --query "Reservations[0].Instances[0].State.Name" --output text 2>/dev/null)
if [ "$STATE" == "running" ]; then
  pass "EC2 instance state: running"
else
  fail "EC2 instance state: $STATE (expected: running)"
fi

# 1.2 Public IP matches what Terraform/AWS both report
AWS_IP=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" \
  --query "Reservations[0].Instances[0].PublicIpAddress" --output text 2>/dev/null)
if [ "$AWS_IP" == "$PUBLIC_IP" ]; then
  pass "Public IP matches AWS record ($AWS_IP)"
else
  warn "IP mismatch - Terraform state says $PUBLIC_IP, AWS says $AWS_IP (state may be stale, or IP changed after a restart - re-run sync_deploy.sh)"
fi

# 1.3 Security group has required ports open
for PORT in 22 "$APP_PORT"; do
  OPEN=$(aws ec2 describe-security-groups --group-ids "$SG_ID" \
    --query "SecurityGroups[0].IpPermissions[?FromPort==\`$PORT\`]" --output text 2>/dev/null)
  if [ -n "$OPEN" ]; then
    pass "Security group allows inbound port $PORT"
  else
    fail "Security group does NOT allow inbound port $PORT"
  fi
done

echo ""

# ==================================================
echo "--- LAYER 2: MIDDLEWARE (Server / Container) ---"
# ==================================================

# 2.1 SSH reachability
if ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 -i "$KEY_PATH" \
    ubuntu@"$PUBLIC_IP" "echo ok" > /dev/null 2>&1; then
  pass "SSH reachable on $PUBLIC_IP"
else
  fail "SSH NOT reachable on $PUBLIC_IP - stopping further server-level checks"
  echo ""
  echo "--- LAYER 3: APPLICATION ---"
  fail "Skipped - server unreachable"
  echo ""
  echo "=================================================="
  echo "SUMMARY: $PASS passed, $WARN warnings, $FAIL failed"
  echo "=================================================="
  exit 1
fi

# 2.2 Docker daemon running
if ssh -o StrictHostKeyChecking=no -i "$KEY_PATH" ubuntu@"$PUBLIC_IP" \
    "systemctl is-active docker" 2>/dev/null | grep -q "^active$"; then
  pass "Docker daemon is active"
else
  fail "Docker daemon is NOT active"
fi

# 2.3 Container running
CONTAINER_STATUS=$(ssh -o StrictHostKeyChecking=no -i "$KEY_PATH" ubuntu@"$PUBLIC_IP" \
  "docker inspect visa-tracker --format='{{.State.Status}}'" 2>/dev/null)
if [ "$CONTAINER_STATUS" == "running" ]; then
  pass "Container 'visa-tracker' is running"
else
  fail "Container 'visa-tracker' status: ${CONTAINER_STATUS:-not found}"
fi

# 2.4 Restart policy correctly set
RESTART_POLICY=$(ssh -o StrictHostKeyChecking=no -i "$KEY_PATH" ubuntu@"$PUBLIC_IP" \
  "docker inspect visa-tracker --format='{{.HostConfig.RestartPolicy.Name}}'" 2>/dev/null)
if [ "$RESTART_POLICY" == "always" ]; then
  pass "Restart policy correctly set to 'always'"
else
  warn "Restart policy is '$RESTART_POLICY' (expected 'always') - container won't survive a reboot without manual intervention"
fi

# 2.5 Basic host resource check
DISK_USAGE=$(ssh -o StrictHostKeyChecking=no -i "$KEY_PATH" ubuntu@"$PUBLIC_IP" \
  "df -h / | awk 'NR==2 {print \$5}'" 2>/dev/null)
echo "  [INFO] Disk usage on /: ${DISK_USAGE:-unknown}"

echo ""

# ==================================================
echo "--- LAYER 3: APPLICATION ---"
# ==================================================

# 3.1 HTTP reachability
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "http://${PUBLIC_IP}:${APP_PORT}")
if [ "$HTTP_CODE" == "200" ]; then
  pass "App responds with HTTP 200 on port $APP_PORT"
else
  fail "App responded with HTTP $HTTP_CODE (expected 200)"
fi

# 3.2 Response time
RESPONSE_TIME=$(curl -s -o /dev/null -w "%{time_total}" --max-time 10 "http://${PUBLIC_IP}:${APP_PORT}")
echo "  [INFO] Response time: ${RESPONSE_TIME}s"

# 3.3 Docker's own healthcheck status (if configured)
DOCKER_HEALTH=$(ssh -o StrictHostKeyChecking=no -i "$KEY_PATH" ubuntu@"$PUBLIC_IP" \
  "docker inspect visa-tracker --format='{{.State.Health.Status}}'" 2>/dev/null)
if [ "$DOCKER_HEALTH" == "healthy" ]; then
  pass "Docker healthcheck status: healthy"
elif [ -n "$DOCKER_HEALTH" ]; then
  warn "Docker healthcheck status: $DOCKER_HEALTH"
else
  warn "No Docker healthcheck configured on this container"
fi

echo ""
echo "=================================================="
echo "SUMMARY: $PASS passed, $WARN warnings, $FAIL failed"
echo "=================================================="

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
