#!/usr/bin/env sh
set -eu

project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
env_file=${ENV_FILE:-"$project_dir/.env"}

if ! command -v ip >/dev/null 2>&1; then
  printf '%s\n' "Erreur: la commande ip est requise pour détecter l'adresse LAN." >&2
  exit 1
fi

host_ip=$(
  ip -4 route get 1.1.1.1 2>/dev/null |
    awk '{
      for (position = 1; position < NF; position++) {
        if ($position == "src" && $(position + 1) ~ /^[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*$/) {
          print $(position + 1)
          exit
        }
      }
    }'
)

case "$host_ip" in
  ""|127.*|169.254.*|224.*|225.*|226.*|227.*|228.*|229.*|230.*|231.*|232.*|233.*|234.*|235.*|236.*|237.*|238.*|239.*)
    printf '%s\n' "Erreur: impossible de déterminer une IPv4 LAN valide." >&2
    exit 1
    ;;
esac

if [ ! -f "$env_file" ]; then
  printf '%s\n' "Erreur: fichier .env introuvable: $env_file" >&2
  exit 1
fi

server_url="wss://$host_ip/ws"
api_url="https://$host_ip"
allowed_origins="$api_url,https://localhost"

case "$env_file" in
  /*) : ;;
  *) printf '%s\n' "Erreur: ENV_FILE doit être un chemin absolu." >&2; exit 1 ;;
esac

tmp_file="$env_file.tmp.$$"
trap 'rm -f "$tmp_file"' EXIT HUP INT TERM

awk -v host_ip="$host_ip" \
    -v server_url="$server_url" \
    -v api_url="$api_url" \
  -v allowed_origins="$allowed_origins" '
BEGIN {
  value["HOST_IP"] = host_ip
  value["QUIZ_SERVER_URL"] = server_url
  value["QUIZ_API_URL"] = api_url
  value["ALLOWED_ORIGINS"] = allowed_origins
}
{
  key = ""
  if ($0 ~ /^HOST_IP=/) key = "HOST_IP"
  else if ($0 ~ /^QUIZ_SERVER_URL=/) key = "QUIZ_SERVER_URL"
  else if ($0 ~ /^QUIZ_API_URL=/) key = "QUIZ_API_URL"
  else if ($0 ~ /^ALLOWED_ORIGINS=/) key = "ALLOWED_ORIGINS"

  if (key != "") {
    if (++seen[key] > 1) {
      print "Erreur: variable dupliquée: " key > "/dev/stderr"
      failed = 1
    } else {
      print key "=" value[key]
    }
  } else {
    print
  }
}
END {
  for (key in value) {
    if (!seen[key]) print key "=" value[key]
  }
  exit failed
}
' "$env_file" > "$tmp_file"

chmod --reference="$env_file" "$tmp_file" 2>/dev/null || true
mv "$tmp_file" "$env_file"
trap - EXIT HUP INT TERM
printf 'Configuration réseau préparée pour %s dans %s\n' "$host_ip" "$env_file"
