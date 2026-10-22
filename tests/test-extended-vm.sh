#!/bin/bash
# Extended Profile VM Test for v1.0.3
# Tests: make up-client-extended -> client-health (all healthy)

set -euo pipefail

echo "===== EXTENDED PROFILE VM TEST START ====="
date -u

echo "--- SYSTEM ---"
. /etc/os-release
echo "ID=$ID VERSION=$VERSION_ID PRETTY=$PRETTY_NAME"
uname -r
nproc
free -m | head -2
df -h / | tail -1

echo "--- PRE-STATE ---"
for c in make docker git ufw tailscale; do
  if command -v "$c" >/dev/null; then echo "PRE_$c=present"; else echo "PRE_$c=MISSING"; fi
done

echo "--- REPO ENTPACKEN ---"
cd /root || exit 1
tar -xzf /root/repo.tar.gz -C /root
cd /root/co-glitch || { echo "REPO_EXTRACT_FAILED"; exit 1; }
chmod +x scripts/*.sh bootstrap.sh
echo "SCRIPT_COUNT=$(ls -1 scripts/*.sh | wc -l)"

echo "--- TEST 0: make vorhanden? ---"
if command -v make >/dev/null; then
  echo "T0_make_present=OK"
else
  echo "T0_make_present=MISSING"
  apt-get update -qq
  DEBIAN_FRONTEND=noninteractive apt-get install -y make
  echo "T0_workaround_installed=$(command -v make)"
fi

echo "--- TEST 1: make gen-secrets ---"
make gen-secrets
echo "EXIT_gen_secrets=$?"
stat -c 'ENV_PERMS=%a' .env

echo "--- TEST 2: make client-setup ---"
START=$(date +%s); make client-setup; RC=$?; END=$(date +%s)
echo "EXIT_client_setup=$RC  DAUER=$((END-START))s"

echo "--- TEST 3: UFW ---"
ufw status verbose
echo "EXIT_ufw=$?"

echo "--- TEST 4: Services ---"
systemctl is-active docker; echo "EXIT_docker_active=$?"
systemctl is-enabled docker; echo "EXIT_docker_enabled=$?"
systemctl is-active fail2ban; echo "EXIT_fail2ban_active=$?"
docker --version
docker compose version
tailscale version | head -1

echo "--- TEST 5: make up-client-extended ---"
START=$(date +%s); timeout 300 make up-client-extended; RC=$?; END=$(date +%s)
echo "EXIT_up_client_extended=$RC  DAUER=$((END-START))s"

echo "--- TEST 6: 180s warten auf Container-Health ---"
sleep 180

echo "--- TEST 6a: Container Status ---"
docker ps --format '{{.Names}}\t{{.Status}}' | sort
echo "CONTAINER_RUNNING=$(docker ps -q | wc -l)"
echo "CONTAINER_TOTAL=$(docker ps -aq | wc -l)"

echo "--- TEST 7: make client-health (Extended, KRITISCH: muss Exit 0) ---"
make client-health
EXIT_CLIENT_HEALTH=$?
echo "EXIT_client_health=$EXIT_CLIENT_HEALTH"

echo "--- TEST 8: make doctor ---"
make doctor
EXIT_DOCTOR=$?
echo "EXIT_doctor=$EXIT_DOCTOR"

echo "--- TEST 9: make down-client-extended ---"
make down-client-extended
echo "EXIT_down_client_extended=$?"
docker ps --filter 'label=co-glitch.tier=client' --format '{{.Names}}' | wc -l | xargs -I{} echo "CONTAINERS_AFTER_DOWN={}"

echo "===== EXTENDED PROFILE VM TEST END ====="
date -u
sync
poweroff -f
