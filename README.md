# Debian-Based NAS Setup: A Complete Guide to Accessing Your Storage Device from Anywhere in the World

Debian can be run on virtually any computer found today. This guide is useful for conversion of old computers to NAS systems.

## Before Getting Started: Requirements
A Computer that has the following:
- Dual-core processor or higher
- 4 GB RAM minimum (non-ZFS)
- 8 GB RAM or more (recommended for ZFS)
- Storage: User-defined  
  - Minimum 50 GB required for the OS and services
- Network connectivity (Ethernet or Wi-Fi)
  
### Network Requirements
This NAS is designed for both local and remote access.

In BOTH cases, Ethernet is always recommended.

(As it is primarily a "repurpose" project, a WiFi Card will also work.)

> **NOTE:** *Visit the Debian Documentation for the list of Supported WiFi Cards before beginning this project.*

#### Local Network (LAN)
- Legacy WiFi cards (100 Mbps rated) are widely supported
  - Real-world throughput may be ~25–40 Mbps
  - Suitable for light NAS workloads

#### Internet (Remote Access via Tailscale)
- Minimum 40 Mbps internet connection
> *Performance when accessing files remotely depends entirely on ISP bandwidth*


## Setup
This Debian NAS Setup has the following functionalities:
- Debian 12
- Web-based management interface
- Dockerized core services
- Resilience scripts (watchdogs)
- Security
- Automation and monitoring
- Documentation and configuration management
