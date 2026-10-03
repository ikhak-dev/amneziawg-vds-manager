#!/usr/bin/env bash

set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=amneziawg-vds-manager.sh
source "$ROOT_DIR/amneziawg-vds-manager.sh"

failures=0

expect_success() {
  local name="$1"
  shift
  if "$@"; then
    printf 'ok - %s\n' "$name"
  else
    printf 'not ok - %s\n' "$name"
    failures=$((failures + 1))
  fi
}

expect_failure() {
  local name="$1"
  shift
  if "$@"; then
    printf 'not ok - %s\n' "$name"
    failures=$((failures + 1))
  else
    printf 'ok - %s\n' "$name"
  fi
}

expect_success "valid IPv4" valid_ipv4 "203.0.113.7"
expect_failure "reject IPv4 octet over 255" valid_ipv4 "203.0.113.999"
expect_failure "reject incomplete IPv4" valid_ipv4 "203.0.113"
expect_success "valid UDP port" valid_port "51820"
expect_failure "reject port zero" valid_port "0"
expect_failure "reject port over 65535" valid_port "65536"
expect_success "valid client name" valid_client_name "laptop_01"
expect_failure "reject unsafe client name" valid_client_name "../../root"
expect_success "valid email" valid_email "user+vpn@example.org"
expect_failure "reject malformed email" valid_email "user@example"
expect_success "valid /24 network" valid_ipv4_cidr_24 "10.66.0.0/24"
expect_failure "reject non-network /24 address" valid_ipv4_cidr_24 "10.66.0.1/24"
expect_success "valid SMTP host" valid_smtp_value "smtp.example.org"
expect_failure "reject SMTP whitespace" valid_smtp_value "smtp example.org"

if [[ "$(format_endpoint_host '2001:db8::1')" == "[2001:db8::1]" ]]; then
  printf 'ok - bracket IPv6 endpoint\n'
else
  printf 'not ok - bracket IPv6 endpoint\n'
  failures=$((failures + 1))
fi

if [[ "$(format_endpoint_host 'vpn.example.org')" == "vpn.example.org" ]]; then
  printf 'ok - preserve DNS endpoint\n'
else
  printf 'not ok - preserve DNS endpoint\n'
  failures=$((failures + 1))
fi

marker="$(mktemp)"
rm -f "$marker"
apt-get() { printf 'called\n' > "$marker"; }
export -f apt-get
printf 'n\n' | setup_mail_sender >/dev/null
if [[ ! -e "$marker" ]]; then
  printf 'ok - SMTP cancellation occurs before package installation\n'
else
  printf 'not ok - SMTP cancellation occurs before package installation\n'
  failures=$((failures + 1))
fi
rm -f "$marker"

smtp_dir="$(mktemp -d)"
MSMTP_CONF="$smtp_dir/msmtprc"
MSMTP_PASS_FILE="$smtp_dir/mail.pass"
MUTT_CONF="$smtp_dir/muttrc"
printf 'y\nsmtp.example.org\n587\nuser@example.org\n\ntest-app-password\n' | setup_mail_sender >/dev/null

for secret_file in "$MSMTP_CONF" "$MSMTP_PASS_FILE" "$MUTT_CONF"; do
  if [[ -f "$secret_file" ]]; then
    printf 'ok - SMTP file created: %s\n' "$(basename "$secret_file")"
  else
    printf 'not ok - SMTP file created: %s\n' "$(basename "$secret_file")"
    failures=$((failures + 1))
  fi
done

if ! grep -q 'test-app-password' "$MSMTP_CONF"; then
  printf 'ok - SMTP password is separated from configuration\n'
else
  printf 'not ok - SMTP password is separated from configuration\n'
  failures=$((failures + 1))
fi

if [[ "$(uname -s)" != MINGW* ]]; then
  for secret_file in "$MSMTP_CONF" "$MSMTP_PASS_FILE" "$MUTT_CONF"; do
    if [[ "$(stat -c '%a' "$secret_file")" == "600" ]]; then
      printf 'ok - private permissions: %s\n' "$(basename "$secret_file")"
    else
      printf 'not ok - private permissions: %s\n' "$(basename "$secret_file")"
      failures=$((failures + 1))
    fi
  done
fi
rm -rf "$smtp_dir"
rm -f "$marker"

if (( failures > 0 )); then
  printf '%d test(s) failed\n' "$failures" >&2
  exit 1
fi

printf 'All function tests passed.\n'
