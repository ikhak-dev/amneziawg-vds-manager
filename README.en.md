# AmneziaWG VDS Manager

[Русский](README.md) | **English**

[![Tests](https://github.com/ikhak-dev/amneziawg-vds-manager/actions/workflows/tests.yml/badge.svg?branch=v3.0)](https://github.com/ikhak-dev/amneziawg-vds-manager/actions/workflows/tests.yml)
[![Security audit](https://github.com/ikhak-dev/amneziawg-vds-manager/actions/workflows/security-audit.yml/badge.svg?branch=v3.0)](https://github.com/ikhak-dev/amneziawg-vds-manager/actions/workflows/security-audit.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-darkorange.svg)](LICENSE)

An interactive Bash manager for installing and operating AmneziaWG on a Debian or Ubuntu VDS. The VDS acts as the central VPN server; computers, laptops, and phones connect as clients and receive private VPN addresses.

## Version

Current manager version: **v3.0.2**  
Generated protocol profile: **AmneziaWG 3.1**

The 3.1 profile includes `HeaderProtectionKey`, randomized traffic padding and timing, `RandomTrailers`, and `DisableCookies`. Older AmneziaWG clients and standard WireGuard clients cannot use this configuration.

## Features

- installs and configures AmneziaWG;
- creates and manages the `awg0` interface;
- generates server and client keys and configuration files;
- adds, displays, exports, and removes clients;
- displays client QR codes;
- supports VPN-only and full-tunnel client modes;
- routes traffic between clients through the VDS;
- configures IPv4 forwarding and `iptables` NAT;
- safely updates an existing server to AmneziaWG 3.1;
- can send a client configuration through an external SMTP service;
- detects missing kernel headers and an incompatible DKMS module;
- keeps backups before changing an existing configuration.

## Quick start

Run the immutable v3.0.2 release:

```bash
curl -fsSL https://raw.githubusercontent.com/ikhak-dev/amneziawg-vds-manager/v3.0.2/amneziawg-vds-manager.sh -o amneziawg-vds-manager.sh
chmod +x amneziawg-vds-manager.sh
sudo bash amneziawg-vds-manager.sh
```

To follow the maintained `v3.0` branch instead, replace `v3.0.2` in the URL with `v3.0`.

## Supported systems

Ubuntu with `systemd` and `apt` is the primary supported platform.

Debian 12 and 13 are supported experimentally. The installer currently obtains AmneziaWG packages from the Ubuntu `focal` PPA, so DKMS compatibility depends on the running kernel and the availability of matching headers.

If the exact headers for the running kernel are unavailable, the manager installs a matching standard kernel and header metapackage and asks you to reboot. Run the manager again after reboot. It never reboots the server automatically.

## Network layout

The default private network is:

```text
VDS       10.66.0.1
Client 1  10.66.0.2
Client 2  10.66.0.3
Phone     10.66.0.4
```

Each device must have its own client configuration. Reusing one `.conf` file on multiple devices causes key, address, and endpoint conflicts.

The default server port is `51820/UDP`. If you select another port during installation, open that UDP port in the provider firewall or security group.

## Client modes

The manager offers two routing modes:

1. **VPN network only** — routes only `10.66.0.0/24`; clients can reach the server and one another while regular Internet traffic remains local.
2. **Full tunnel** — routes all client Internet traffic through the VDS.

Client files are stored in:

```text
/root/amneziawg-clients/
```

## Updating an existing server to AmneziaWG 3.1

Start the current manager and select:

```text
11) Update an existing installation to AmneziaWG 3.1
```

The manager updates the packages, verifies the userspace tools and kernel module, backs up existing configurations under `/root/amneziawg-backups/`, updates the server and saved client profiles, and restarts `awg0`.

Import the regenerated client configuration on every device after the update. The 3.1 parameters must match on both ends.

Verify the installed versions with:

```bash
awg --version
modinfo -F version amneziawg
cat /sys/module/amneziawg/version
```

All three results must support AmneziaWG 3.1.

## SMTP security warning

SMTP delivery sends a client `.conf` file, including its private key, through an external mail service. A wrong recipient address or a compromised mailbox can give another person VPN access.

- verify the recipient before sending;
- use a separate application password;
- never use your primary mailbox password;
- remove and recreate a client if its configuration may have leaked.

The SMTP password is stored separately on the VDS with mode `600`. SMTP configuration is optional and requires an explicit confirmation in the menu.

## Troubleshooting

### `Unable to modify interface: Invalid argument`

Compare the tools and module versions:

```bash
awg --version
modinfo -F version amneziawg
cat /sys/module/amneziawg/version 2>/dev/null
apt-cache policy amneziawg-dkms
```

This error commonly means that the 3.1 tools are being used with an older kernel module. Update DKMS and reload the module, or reboot if the module is busy.

### `Module amneziawg not found`

Check the kernel headers and DKMS state:

```bash
uname -r
ls -ld "/lib/modules/$(uname -r)/build"
dkms status
modinfo -F version amneziawg
```

If the manager installs a newer kernel and asks for a reboot, reboot the VDS and run the manager again.

### No client connection

Inspect incoming UDP traffic on the server:

```bash
sudo tcpdump -ni any udp port 51820
```

If no packets arrive while the client is connecting, check the provider firewall, the configured UDP port, and the client `Endpoint`.

## Quality and security checks

Every change to `v3.0` runs:

- Bash syntax validation and ShellCheck;
- functional tests on Ubuntu 22.04, 24.04, and 26.04;
- full-history secret scanning with Gitleaks;
- secret and configuration scanning with Trivy;
- GitHub Actions validation with actionlint and zizmor;
- repository security posture analysis with OpenSSF Scorecard.

The badges at the top show the current results. The workflows use minimal token permissions and pin third-party Actions to full commit SHAs.

## License and third-party software

The manager's original code is released under the [MIT License](LICENSE). Third-party components retain their own licenses; see [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

This is an independent project and is not affiliated with AmneziaVPN, WireGuard, or their respective maintainers.

## Reporting security issues

Do not put credentials, private keys, client configurations, or details of an unfixed vulnerability in a public issue. Follow the private reporting instructions in [SECURITY.md](SECURITY.md).
