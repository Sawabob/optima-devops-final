#!/usr/bin/env bash
set -euo pipefail

key="$RUNNER_TEMP/study-board-key"
console="$RUNNER_TEMP/study-board-console.log"
known_hosts="$RUNNER_TEMP/study-board-known_hosts"
host_key=""

for attempt in {1..30}; do
  if aws ec2 get-console-output --instance-id "$INSTANCE_ID" --latest --query Output --output text > "$console"; then
    host_key=$(grep -m1 -oE 'STUDY_BOARD_HOST_KEY ssh-ed25519 [A-Za-z0-9+/=]+' "$console" | cut -d ' ' -f 2- || true)
  fi
  if [[ -n "$host_key" ]]; then
    break
  fi
  sleep 8
done

if [[ -z "$host_key" ]]; then
  echo 'AWS did not report the SSH host key after Docker setup.' >&2
  exit 1
fi

printf '%s %s\n' "$INSTANCE_IP" "$host_key" > "$known_hosts"
image="docker.io/$DOCKER_USERNAME/optima-study-board:$GITHUB_SHA"
ssh -i "$key" -o BatchMode=yes -o IdentitiesOnly=yes -o StrictHostKeyChecking=yes \
  -o "UserKnownHostsFile=$known_hosts" -o ConnectTimeout=15 "ubuntu@$INSTANCE_IP" \
  bash -s -- "$image" <<'REMOTE'
set -euo pipefail
image="${1:?Missing image name}"
sudo cloud-init status --wait
sudo docker pull "$image"
if sudo docker container inspect study-board >/dev/null 2>&1; then
  sudo docker rm -f study-board >/dev/null
fi
sudo docker run -d --name study-board --restart unless-stopped -p 3000:3000 \
  --read-only --cap-drop ALL --security-opt no-new-privileges:true "$image"
curl --retry 8 --retry-connrefused -fsS http://127.0.0.1:3000/healthz
REMOTE

url="http://$INSTANCE_IP:3000"
curl --retry 8 --retry-connrefused --connect-timeout 8 -fsS "$url/healthz" | grep -Fx '{"status":"ok"}'
curl --connect-timeout 8 -fsS "$url/" | grep -F '<h1>Навчальні дедлайни</h1>'
printf 'Study board returned HTTP 200 on port 3000.\n' >> "$GITHUB_STEP_SUMMARY"
