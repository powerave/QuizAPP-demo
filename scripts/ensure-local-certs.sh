#!/bin/bash
set -eu

cert_dir=${CERT_DIR:-certs}
cert_file="$cert_dir/fullchain.pem"
key_file="$cert_dir/privkey.pem"

# Charger HOST_IP depuis le .env si elle n'est pas transmise dans l'environnement
if [ -z "${HOST_IP:-}" ] && [ -f .env ]; then
  HOST_IP=$(grep -oP '^HOST_IP=\K.*' .env || true)
fi

host_ip=${HOST_IP:-}

has_host_ip() {
  [ -n "$host_ip" ] || return 0
  openssl x509 -in "$cert_file" -noout -ext subjectAltName 2>/dev/null |
    awk -v wanted="$host_ip" '
      /Subject Alternative Name:/ { in_san = 1; next }
      in_san {
        count = split($0, fields, ",")
        for (position = 1; position <= count; position++) {
          value = fields[position]
          gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
          if (value == "IP Address:" wanted) found = 1
        }
      }
      END { exit(found ? 0 : 1) }
    '
}

if [ -f "$cert_file" ] && [ -f "$key_file" ]; then
  openssl x509 -in "$cert_file" -noout >/dev/null
  openssl pkey -in "$key_file" -noout >/dev/null
  if has_host_ip; then
    printf 'Certificats HTTPS locaux valides dans %s\n' "$cert_dir"
    exit 0
  fi
  if [ -z "$host_ip" ]; then
    printf 'Certificats HTTPS locaux valides dans %s\n' "$cert_dir"
    exit 0
  fi
  printf 'L’adresse %s manque du certificat; régénération nécessaire.\n' "$host_ip"
fi

if { [ -e "$cert_file" ] || [ -e "$key_file" ]; } &&
   ! { [ -f "$cert_file" ] && [ -f "$key_file" ] && [ -n "$host_ip" ]; }; then
  printf 'Erreur: certs incomplets dans %s; aucun fichier existant ne sera écrasé.\n' "$cert_dir" >&2
  exit 1
fi

if ! command -v mkcert >/dev/null 2>&1; then
  printf 'Erreur: mkcert est requis pour générer les certificats locaux.\n' >&2
  printf 'Installez mkcert puis relancez ce script.\n' >&2
  exit 1
fi

if ! command -v openssl >/dev/null 2>&1; then
  printf '%s\n' "Erreur: openssl est requis pour contrôler les certificats." >&2
  exit 1
fi

mkdir -p "$cert_dir"
mkcert -install
temporary_dir=$(mktemp -d)
trap 'rm -rf "$temporary_dir"' EXIT HUP INT TERM
temporary_cert="$temporary_dir/fullchain.pem"
temporary_key="$temporary_dir/privkey.pem"
if [ -n "$host_ip" ]; then
  mkcert \
    -cert-file "$temporary_cert" \
    -key-file "$temporary_key" \
    localhost 127.0.0.1 ::1 "$host_ip"
else
  mkcert \
    -cert-file "$temporary_cert" \
    -key-file "$temporary_key" \
    localhost 127.0.0.1 ::1
fi

openssl x509 -in "$temporary_cert" -noout >/dev/null
openssl pkey -in "$temporary_key" -noout >/dev/null
mv "$temporary_cert" "$cert_file"
mv "$temporary_key" "$key_file"
trap - EXIT HUP INT TERM
printf 'Certificats HTTPS locaux générés dans %s\n' "$cert_dir"