# Network Setup Guide - Policy-Based Routing for Media Center

This guide provides step-by-step instructions for setting up policy-based routing on Armbian to segregate container traffic through different network paths.

## Network Architecture Overview

Our setup uses three VLANs to create isolated network paths:

- **VLAN 120**: Default VLAN for servers (management network)
- **VLAN 160**: Normal internet access for containers
- **VLAN 170**: VPN-tunneled internet access for containers

### Complete Network Infrastructure

This setup requires proper upstream network infrastructure to provide the different internet access paths:

```
Internet (WAN)
      │
┌─────┴─────┐
│  Router/  │
│ Firewall  │
└─────┬─────┘
      │
┌─────┴─────┐
│  Layer 3  │
│  Switch   │
│  (Core)   │
└─────┬─────┘
      │
┌─────┴─────┐
│  Layer 2  │
│  Switch   │ ── VLAN 120 (Management): 10.2.4.0/24    → Direct WAN
│ (Access)  │ ── VLAN 160 (Normal):     192.168.70.0/24 → Direct WAN  
│           │ ── VLAN 170 (VPN):        192.168.71.0/24 → VPN Gateway
└─────┬─────┘
      │
┌─────┴─────┐
│Container  │
│   Host    │ ── eth0 (Trunk: VLANs 120,160,170)
│ (Armbian) │
└───────────┘
```

### Upstream Requirements

Your network infrastructure must provide:

1. **VLAN 120 Gateway (10.2.4.1)**:
   - Direct internet access for server management
   - DNS resolution
   - NTP access
   - SSH access for administration

2. **VLAN 160 Gateway (192.168.70.1)**:
   - Direct internet access (normal routing)
   - Used by cloudflared for tunnel connectivity
   - Should have unrestricted access to Cloudflare endpoints

3. **VLAN 170 Gateway (192.168.71.1)**:
   - VPN-tunneled internet access
   - All traffic routed through VPN (PIA or other)
   - May have restricted access to certain endpoints
   - Higher latency than normal internet

### Router/Firewall Configuration Required

Your upstream router/firewall needs to be configured with:

```bash
# VLAN 160 - Normal Internet Route
VLAN 160 (192.168.70.0/24) → WAN Interface (Direct)

# VLAN 170 - VPN Internet Route  
VLAN 170 (192.168.71.0/24) → VPN Interface/Gateway

# VLAN 120 - Management Route
VLAN 120 (10.2.4.0/24) → WAN Interface (Direct)
```

## Environment Variables

### Network Configuration
```bash
# VLAN Configuration
VLAN_SERVERS=120                    # Default VLAN on switch port
VLAN_CONTAINERS_INTERNET=160        # Normal internet containers
VLAN_CONTAINERS_PIA=170            # VPN internet containers

# Server Network (VLAN 120 - Management)
SERVERS_NETWORK=10.2.4.0/24
SERVERS_IP=10.2.4.10
SERVERS_GATEWAY=10.2.4.1            # Must route to WAN

# Containers Internet Network (VLAN 160)
CONTAINERS_INTERNET_NETWORK=192.168.70.0/24
CONTAINERS_INTERNET_GATEWAY=192.168.70.1    # Must route to WAN (direct)

# Containers PIA Internet Network (VLAN 170)  
CONTAINERS_PIA_NETWORK=192.168.71.0/24
CONTAINERS_PIA_GATEWAY=192.168.71.1         # Must route to WAN (via VPN)

# Docker Bridge Networks
DOCKER_LOCAL_NETWORK=172.25.0.0/24      # Internal communication only
DOCKER_INTERNET_NETWORK=172.26.0.0/24   # Normal internet (cloudflared)
DOCKER_PIA_NETWORK=172.27.0.0/24        # VPN internet (media services)
```

## Prerequisites

1. Armbian system with systemd
2. Root access
3. Network switch supporting VLANs
4. Properly configured VLANs on your network infrastructure
5. **Upstream router/firewall with VLAN and VPN routing capabilities**

### Network Infrastructure Requirements

#### Option 1: Router-Based VPN (Recommended)
Your router/firewall handles the VPN connection for VLAN 170:

**Advantages:**
- Centralized VPN management
- All VLAN 170 traffic automatically uses VPN
- No VPN configuration needed on container host
- Better performance (hardware acceleration)
- Easier to manage multiple devices

**Requirements:**
- Router supporting policy-based routing
- VPN client capability on router (OpenVPN, WireGuard, etc.)
- VLAN configuration on router
- Separate routing tables for different VLANs

**Example Router Configuration (pfSense/OPNsense):**
```bash
# Interface assignments
VLAN120_IF -> WAN_GW (Direct)
VLAN160_IF -> WAN_GW (Direct)  
VLAN170_IF -> VPN_GW (PIA/NordVPN/etc.)

# Firewall rules
VLAN120: Allow all to WAN
VLAN160: Allow all to WAN
VLAN170: Force all traffic through VPN gateway
```

#### Option 2: Container Host VPN (Alternative)
The container host itself connects to VPN for VLAN 170 traffic:

**Advantages:**
- No router VPN configuration needed
- More control over VPN settings
- Can use container-specific VPN configurations

**Disadvantages:**
- More complex configuration
- VPN overhead on container host
- Single point of failure
- Additional CPU/memory usage

**Additional Requirements if using this approach:**
- VPN client software on Armbian host
- Additional network namespaces or VPN interfaces
- Modified routing script to route through VPN interface

#### Option 3: Per-Container VPN (Most Complex)
Individual containers use VPN connections:

**Note:** This approach is not covered in this guide but involves VPN containers or VPN-enabled application containers.

### Recommended Network Equipment

For a robust setup, consider:

1. **Managed Switch with VLAN Support:**
   - Cisco, HPE, or Ubiquiti switches
   - Proper VLAN tagging and trunking
   - Quality of Service (QoS) support

2. **Router/Firewall with VPN Support:**
   - pfSense or OPNsense (recommended)
   - Ubiquiti Dream Machine
   - Enterprise-grade routers with VPN client support

3. **VPN Service:**
   - Private Internet Access (PIA)
   - NordVPN, ExpressVPN, or similar
   - WireGuard or OpenVPN compatible

## Verification of Upstream Infrastructure

Before proceeding with container host configuration, verify your network infrastructure:

```bash
# Test VLAN connectivity from another device
# Connect to VLAN 160 and test internet access
ping 8.8.8.8
curl -s http://httpbin.org/ip  # Should show your normal public IP

# Connect to VLAN 170 and test VPN internet access  
ping 8.8.8.8
curl -s http://httpbin.org/ip  # Should show your VPN public IP
```

## Step 1: Install Required Packages

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install required packages
sudo apt install -y netplan.io vlan iproute2 iptables-persistent

# Check if netplan is available (it should be on modern Armbian)
netplan --version
```

## Step 2: Configure VLAN Interfaces with Netplan

First, backup any existing network configuration:

```bash
# Backup existing netplan configuration
sudo cp -r /etc/netplan /etc/netplan.backup

# Remove any existing systemd-networkd configuration if present
sudo rm -f /etc/systemd/network/*.network /etc/systemd/network/*.netdev
```

Create the netplan configuration file:

```bash
sudo nano /etc/netplan/01-netcfg.yaml
```

Add the following configuration (keeping your existing VLANs and adding the media center ones):

```yaml
network:
  version: 2
  renderer: networkd
  ethernets:
    zz-all-en:
      dhcp4: false
      match:
        name: en*
      optional: false
  
  bonds:
    bond0:
      interfaces: [zz-all-en]
      addresses: [10.2.4.10/24]
      routes:
        - to: default
          via: 10.2.4.1
          metric: 100
      nameservers:
        addresses: [10.2.4.1]
      parameters:
        mode: 802.3ad
        lacp-rate: fast
        mii-monitor-interval: 100
        transmit-hash-policy: layer3+4
  
  vlans:
    # Your existing VLANs (kept as-is)
    vlan.1:
      id: 1
      link: bond0
    
    vlan.130:
      id: 130
      link: bond0
    
    vlan.150:
      id: 150
      link: bond0
    
    vlan.3:
      id: 3
      link: bond0
    
    # Additional VLANs for media center routing
    vlan.120:
      id: 120
      link: bond0
      # This could be used for additional server management if needed
    
    vlan.160:
      id: 160
      link: bond0
      dhcp4: true
      dhcp6: false
      dhcp4-overrides:
        use-routes: false    # Don't use DHCP routes to avoid conflicts
        use-dns: true       # Don't use DHCP DNS
    
    vlan.170:
      id: 170
      link: bond0
      dhcp4: true
      dhcp6: false
      dhcp4-overrides:
        use-routes: false    # Don't use DHCP routes to avoid conflicts
        use-dns: true       # Don't use DHCP DNS
```

**VLAN Usage Summary:**
- **bond0**: Your existing management interface (10.2.4.10/24)
- **vlan.1, vlan.3, vlan.130, vlan.150**: Your existing VLANs (unchanged)
- **vlan.120**: Additional server management VLAN (optional)
- **vlan.160**: Container internet access (DHCP: 192.168.70.0/24)
- **vlan.170**: Container PIA internet access (DHCP: 192.168.71.0/24)

**Important Notes:**

1. **Your Existing Setup**: All your current VLANs are preserved exactly as you had them
2. **Management**: bond0 continues to handle your primary server management
3. **New VLANs**: Only VLAN 160 and 170 are configured for DHCP for container routing
4. **Flexibility**: You can choose which VLANs to use for container routing

Test and apply the netplan configuration:

```bash
# Test the configuration (doesn't apply changes)
sudo netplan try

# If the test is successful, apply the configuration
sudo netplan apply

# Verify all VLAN interfaces are created
ip addr show | grep vlan

# Check that bond0 is working
ip addr show bond0

# Check routing table (should show bond0 default route)
ip route show
```

## Step 3: Create Custom Routing Tables

Add custom routing tables to the system:

```bash
sudo nano /etc/iproute2/rt_tables
```

Add these lines at the end:

```bash
# Custom routing tables for container networks
100 containers_internet
101 containers_pia_internet
```

## Step 4: Create Policy-Based Routing Script

Create the routing configuration script:

```bash
sudo nano /usr/local/bin/setup-container-routing.sh
```

```bash
#!/bin/bash

# Policy-Based Routing Setup Script for Media Center
# Simple interface-based routing with iptables packet marking

set -e  # Exit on any error

# Configuration
VLAN_CONTAINERS_INTERNET=160
VLAN_CONTAINERS_PIA=170

# Interfaces
MANAGEMENT_IF="bond0"
CONTAINERS_INTERNET_IF="vlan.160"
CONTAINERS_PIA_IF="vlan.170"

# Docker bridge interfaces (user-provided)
DOCKER_INTERNET_BRIDGE="br-5b71b45374c1"
DOCKER_PIA_BRIDGE="br-5e100127347a"

# Networks
SERVERS_NETWORK="10.2.4.0/24"
SERVERS_GATEWAY="10.2.4.1"
DOCKER_INTERNET_NETWORK="172.26.0.0/24"
DOCKER_PIA_NETWORK="172.27.0.0/24"

# Routing tables and marks
RT_CONTAINERS_INTERNET=100
RT_CONTAINERS_PIA=101
MARK_INTERNET=100
MARK_PIA=101

echo "=== Setting up policy-based routing for media center ==="
echo "Internet VLAN: $VLAN_CONTAINERS_INTERNET -> Bridge: $DOCKER_INTERNET_BRIDGE"
echo "PIA VLAN: $VLAN_CONTAINERS_PIA -> Bridge: $DOCKER_PIA_BRIDGE"

# Function to check if interface exists
check_interface() {
    local interface=$1
    local description=$2
    if ! ip link show "$interface" >/dev/null 2>&1; then
        echo "ERROR: $description interface '$interface' not found"
        return 1
    fi
    echo "✓ $description interface '$interface' found"
}

# Function to get interface info
get_interface_info() {
    local interface=$1
    local ip=$(ip addr show "$interface" | grep 'inet ' | awk '{print $2}' | cut -d/ -f1 | head -1)
    local network=$(ip route show dev "$interface" | grep -E "proto (kernel|dhcp)" | awk '{print $1}' | head -1)
    
    # Try multiple methods to get the gateway
    local gateway=""
    
    # Method 1: Look for default route on this interface
    gateway=$(ip route show dev "$interface" | grep "default" | awk '{print $3}' | head -1)
    
    # Method 2: Look for DHCP route information
    if [ -z "$gateway" ]; then
        gateway=$(ip route show dev "$interface" | grep "proto dhcp" | grep "default" | awk '{print $3}' | head -1)
    fi
    
    # Method 3: Check for gateway in the network's routing table
    if [ -z "$gateway" ] && [ -n "$network" ]; then
        # Extract network base (e.g., 192.168.71.0/24 -> 192.168.71)
        local net_base=$(echo "$network" | cut -d'.' -f1-3)
        # Look for routes to this network that might show the gateway
        gateway=$(ip route show | grep "$network" | grep "via" | awk '{print $3}' | head -1)
    fi
    
    # Method 4: Try to get gateway from DHCP lease files
    if [ -z "$gateway" ] && [ -n "$ip" ]; then
        local net_base=$(echo "$ip" | cut -d'.' -f1-3)
        # Common DHCP gateway is .1 in the network
        local possible_gateway="${net_base}.1"
        # Verify this gateway is reachable
        if ping -c 1 -W 1 "$possible_gateway" >/dev/null 2>&1; then
            gateway="$possible_gateway"
        fi
    fi
    
    # Method 5: Check systemd-networkd DHCP lease files
    if [ -z "$gateway" ]; then
        local lease_file="/run/systemd/netif/leases/$(ip link show "$interface" | head -1 | cut -d: -f1)"
        if [ -f "$lease_file" ]; then
            gateway=$(grep "ROUTER=" "$lease_file" | cut -d'=' -f2 | head -1)
        fi
    fi
    
    echo "$ip|$network|$gateway"
}

# Clean up existing configuration
echo "Cleaning up existing routing rules..."
ip rule del table $RT_CONTAINERS_INTERNET 2>/dev/null || true
ip rule del table $RT_CONTAINERS_PIA 2>/dev/null || true
ip rule del fwmark $MARK_INTERNET table $RT_CONTAINERS_INTERNET 2>/dev/null || true
ip rule del fwmark $MARK_PIA table $RT_CONTAINERS_PIA 2>/dev/null || true
ip route flush table $RT_CONTAINERS_INTERNET 2>/dev/null || true
ip route flush table $RT_CONTAINERS_PIA 2>/dev/null || true

# Verify interfaces exist
echo "Checking interfaces..."
check_interface "$MANAGEMENT_IF" "Management"
check_interface "$CONTAINERS_INTERNET_IF" "Internet VLAN"
check_interface "$CONTAINERS_PIA_IF" "PIA VLAN"
check_interface "$DOCKER_INTERNET_BRIDGE" "Docker Internet Bridge"
check_interface "$DOCKER_PIA_BRIDGE" "Docker PIA Bridge"

# Get VLAN interface information
echo "Getting interface information..."
VLAN160_INFO=$(get_interface_info "$CONTAINERS_INTERNET_IF")
VLAN170_INFO=$(get_interface_info "$CONTAINERS_PIA_IF")

VLAN160_IP=$(echo "$VLAN160_INFO" | cut -d'|' -f1)
VLAN160_NETWORK=$(echo "$VLAN160_INFO" | cut -d'|' -f2)
VLAN160_GATEWAY=$(echo "$VLAN160_INFO" | cut -d'|' -f3)

VLAN170_IP=$(echo "$VLAN170_INFO" | cut -d'|' -f1)
VLAN170_NETWORK=$(echo "$VLAN170_INFO" | cut -d'|' -f2)
VLAN170_GATEWAY=$(echo "$VLAN170_INFO" | cut -d'|' -f3)

echo "VLAN 160: IP=$VLAN160_IP, Network=$VLAN160_NETWORK, Gateway=$VLAN160_GATEWAY"
echo "VLAN 170: IP=$VLAN170_IP, Network=$VLAN170_NETWORK, Gateway=$VLAN170_GATEWAY"

# Verify we have the required information
if [ -z "$VLAN160_IP" ] || [ -z "$VLAN170_IP" ]; then
    echo "ERROR: Could not get IP addresses for VLAN interfaces"
    exit 1
fi

# Setup custom routing tables
echo "Setting up routing tables..."

# Internet table (VLAN 160) - Internet only
[ -n "$VLAN160_GATEWAY" ] && ip route add default via "$VLAN160_GATEWAY" dev "$CONTAINERS_INTERNET_IF" table $RT_CONTAINERS_INTERNET
[ -n "$VLAN160_NETWORK" ] && ip route add "$VLAN160_NETWORK" dev "$CONTAINERS_INTERNET_IF" scope link table $RT_CONTAINERS_INTERNET

# PIA table (VLAN 170) - Internet only  
[ -n "$VLAN170_GATEWAY" ] && ip route add default via "$VLAN170_GATEWAY" dev "$CONTAINERS_PIA_IF" table $RT_CONTAINERS_PIA
[ -n "$VLAN170_NETWORK" ] && ip route add "$VLAN170_NETWORK" dev "$CONTAINERS_PIA_IF" scope link table $RT_CONTAINERS_PIA

# Setup fwmark routing rules
echo "Setting up routing rules..."
ip rule add fwmark $MARK_INTERNET table $RT_CONTAINERS_INTERNET priority 100
ip rule add fwmark $MARK_PIA table $RT_CONTAINERS_PIA priority 101

# Setup iptables packet marking
echo "Setting up packet marking..."
iptables -t mangle -F PREROUTING
iptables -t mangle -F OUTPUT

# Mark packets based on Docker bridge interfaces
iptables -t mangle -A PREROUTING -i "$DOCKER_INTERNET_BRIDGE" -j MARK --set-mark $MARK_INTERNET
iptables -t mangle -A PREROUTING -i "$DOCKER_PIA_BRIDGE" -j MARK --set-mark $MARK_PIA

# Setup NAT
echo "Setting up NAT..."
iptables -t nat -F POSTROUTING
iptables -t nat -A POSTROUTING -s "$DOCKER_INTERNET_NETWORK" -o "$CONTAINERS_INTERNET_IF" -j MASQUERADE
iptables -t nat -A POSTROUTING -s "$DOCKER_PIA_NETWORK" -o "$CONTAINERS_PIA_IF" -j MASQUERADE

# Setup forwarding
echo "Setting up forwarding rules..."
iptables -F FORWARD
iptables -A FORWARD -i docker+ -o "$CONTAINERS_INTERNET_IF" -j ACCEPT
iptables -A FORWARD -i "$CONTAINERS_INTERNET_IF" -o docker+ -j ACCEPT
iptables -A FORWARD -i docker+ -o "$CONTAINERS_PIA_IF" -j ACCEPT
iptables -A FORWARD -i "$CONTAINERS_PIA_IF" -o docker+ -j ACCEPT
iptables -A FORWARD -i docker+ -o docker+ -j ACCEPT

# Save configuration
echo "Saving iptables rules..."
iptables-save > /etc/iptables/rules.v4

echo "=== Setup complete! ==="
echo "Configuration summary:"
echo "  Internet routing: $DOCKER_INTERNET_NETWORK -> $CONTAINERS_INTERNET_IF -> $VLAN160_GATEWAY"
echo "  PIA routing: $DOCKER_PIA_NETWORK -> $CONTAINERS_PIA_IF -> $VLAN170_GATEWAY"
echo ""
echo "Verification commands:"
echo "  ip rule show | grep -E '(100|101)'"
echo "  iptables -t mangle -L PREROUTING -n"
echo "  ip route show table $RT_CONTAINERS_INTERNET"
echo "  ip route show table $RT_CONTAINERS_PIA"
```

Make the script executable:

```bash
sudo chmod +x /usr/local/bin/setup-container-routing.sh
```

## Step 5: Create systemd Service

Create a systemd service to run the routing script at boot:

```bash
sudo nano /etc/systemd/system/container-routing.service
```

```ini
[Unit]
Description=Container Policy-Based Routing Setup
After=network-online.target systemd-networkd.service
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/setup-container-routing.sh
RemainAfterExit=yes
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
```

Enable and start the service:

```bash
sudo systemctl daemon-reload
sudo systemctl enable container-routing.service
```

## Step 6: Enable Required Services

Ensure the required services are enabled:

```bash
# Enable systemd-networkd (used by netplan)
sudo systemctl enable systemd-networkd

# Disable conflicting network services
sudo systemctl disable networking  # Disable traditional networking if present
sudo systemctl disable dhcpcd     # Disable dhcpcd if present
sudo systemctl disable NetworkManager  # Disable NetworkManager if present

# Enable systemd-resolved for DNS (recommended with netplan)
sudo systemctl enable systemd-resolved
```

## Alternative: Legacy systemd-networkd Configuration

If netplan is not available on your system, you can use the legacy systemd-networkd configuration instead:

<details>
<summary>Click to expand legacy systemd-networkd configuration</summary>

Create the network configuration file:

```bash
sudo nano /etc/systemd/network/10-vlans.network
```

```ini
[Match]
Name=eth0

[Network]
VLAN=vlan120
VLAN=vlan160
VLAN=vlan170
```

Create VLAN 120 (Servers) configuration:

```bash
sudo nano /etc/systemd/network/11-vlan120.netdev
```

```ini
[NetDev]
Name=vlan120
Kind=vlan

[VLAN]
Id=120
```

```bash
sudo nano /etc/systemd/network/11-vlan120.network
```

```ini
[Match]
Name=vlan120

[Network]
Address=10.2.4.10/24
Gateway=10.2.4.1
DNS=8.8.8.8
DNS=8.8.4.4
```

Create VLAN 160 (Containers Internet) configuration:

```bash
sudo nano /etc/systemd/network/12-vlan160.netdev
```

```ini
[NetDev]
Name=vlan160
Kind=vlan

[VLAN]
Id=160
```

```bash
sudo nano /etc/systemd/network/12-vlan160.network
```

```ini
[Match]
Name=vlan160

[Network]
DHCP=yes
```

Create VLAN 170 (Containers PIA) configuration:

```bash
sudo nano /etc/systemd/network/13-vlan170.netdev
```

```ini
[NetDev]
Name=vlan170
Kind=vlan

[VLAN]
Id=170
```

```bash
sudo nano /etc/systemd/network/13-vlan170.network
```

```ini
[Match]
Name=vlan170

[Network]
DHCP=yes
```

Then enable systemd-networkd:

```bash
sudo systemctl enable systemd-networkd
sudo systemctl restart systemd-networkd
```

</details>

## Step 7: Update Docker Compose Configuration

Update your `docker-compose.yaml` to include the three-tier network architecture:

```yaml
networks:
  # Internal communication only (no internet access)
  media_center_local:
    name: "${CONTAINER_NAME_PREFIX}_local"
    driver: bridge
    ipam:
      config:
        - subnet: 172.25.0.0/24

  # Normal internet access (for cloudflared)
  media_center_internet:
    name: "${CONTAINER_NAME_PREFIX}_internet"
    driver: bridge
    ipam:
      config:
        - subnet: 172.26.0.0/24

  # VPN internet access (for media services)
  media_center_pia:
    name: "${CONTAINER_NAME_PREFIX}_pia"
    driver: bridge
    ipam:
      config:
        - subnet: 172.27.0.0/24

  # Legacy network for backward compatibility
  media_center_apps:
    name: "${MEDIA_CENTER_NETWORK}"

  # Home IoT network (optional)
  home_iot:
    external: ${ENABLE_HOME_IOT_NETWORK:-false}
    name: "${HOME_IOT_NETWORK:-home_iot}"

  # Jellystat database network
  jellystat_db_network:
    name: "${CONTAINER_NAME_PREFIX}_jellystat_db_network"
```

## Step 8: Create External Docker Networks

Before starting your media center stack, you need to create the external Docker networks that will be used for internet routing:

```bash
# Create external Docker networks for container routing
# These networks will be used by the policy-based routing to route traffic

# Create the container internet network (normal internet access)
docker network create \
  --driver bridge \
  --subnet=172.26.0.0/24 \
  --gateway=172.26.0.1 \
  container_internet

# Create the container PIA internet network (VPN internet access)  
docker network create \
  --driver bridge \
  --subnet=172.27.0.0/24 \
  --gateway=172.27.0.1 \
  container_pia_internet

# Verify the networks were created and note their bridge interface names
docker network ls | grep -E "(container_internet|container_pia_internet)"

# Check the bridge interface names
ip link show | grep br-

# Update your bridge interface names in the routing script if they differ
echo "Update DOCKER_INTERNET_BRIDGE and DOCKER_PIA_BRIDGE in the routing script if needed"
```

**Important:** Make note of the bridge interface names (br-xxxxxxxxx) that Docker creates. You may need to update the routing script with the actual interface names if they differ from the examples.

## Step 9: Apply Configuration

1. Reboot the system to apply all changes:
   ```bash
   sudo reboot
   ```

2. After reboot, verify the configuration:
   ```bash
   # Check VLAN interfaces
   ip addr show | grep vlan

   # Check routing tables
   ip route show table containers_internet
   ip route show table containers_pia_internet

   # Check routing rules
   ip rule show

   # Check iptables NAT rules
   sudo iptables -t nat -L POSTROUTING
   ```

3. Create the external Docker networks (if not already created):
   ```bash
   # Run the Docker network creation commands from Step 8
   ```

4. Start your media center stack:
   ```bash
   docker compose up -d
   ```

## Verification

### Test Network Segregation

1. **Check container network assignments**:
   ```bash
   docker network ls
   docker inspect <container_name> | grep NetworkMode
   ```

2. **Test internet connectivity from containers**:
   ```bash
   # Test cloudflared (should use normal internet)
   docker exec media_center_cloudflared curl -s http://httpbin.org/ip

   # Test other services (should use VPN internet)
   docker exec media_center_jellyfin curl -s http://httpbin.org/ip
   ```

3. **Monitor traffic**:
   ```bash
   # Monitor VLAN 160 traffic (normal internet)
   sudo tcpdump -i vlan160 -n

   # Monitor VLAN 170 traffic (VPN internet)
   sudo tcpdump -i vlan170 -n
   ```

## Troubleshooting

### Common Issues

1. **VLAN interfaces not getting IP addresses**:
   - Check switch VLAN configuration
   - Verify DHCP server on respective VLANs
   - Check netplan configuration: `sudo netplan --debug apply`
   - Check systemd-networkd status: `sudo systemctl status systemd-networkd`

2. **Netplan configuration errors**:
   - Validate YAML syntax: `sudo netplan try`
   - Check netplan status: `sudo netplan status`
   - View generated configuration: `sudo netplan get`

3. **Routing rules not working**:
   - Verify routing tables: `ip route show table all`
   - Check rule priority: `ip rule show`
   - Restart container-routing service: `sudo systemctl restart container-routing.service`

4. **Containers can't reach internet**:
   - Check iptables rules: `sudo iptables -L FORWARD -v`
   - Verify NAT rules: `sudo iptables -t nat -L POSTROUTING -v`
   - Check Docker daemon logs: `sudo journalctl -u docker.service`

### Debug Commands

```bash
# Netplan specific commands
sudo netplan status               # Show netplan status
sudo netplan get                  # Show current netplan configuration
sudo netplan --debug apply       # Apply configuration with debug output

# Show all routing tables
ip route show table all

# Show routing rules with priorities
ip rule show

# Test routing from specific source
ip route get 8.8.8.8 from 172.26.0.1  # Should use VLAN 160
ip route get 8.8.8.8 from 172.27.0.1  # Should use VLAN 170

# Check VLAN interface status
sudo systemctl status systemd-networkd
sudo networkctl status vlan160 vlan170

# Monitor routing script execution
sudo journalctl -u container-routing.service -f

# Check DNS resolution (if using systemd-resolved)
sudo systemctl status systemd-resolved
resolvectl status
```

### Troubleshooting Netplan Issues

1. **YAML syntax errors**:
   ```bash
   # Test configuration before applying
   sudo netplan try
   
   # Check for indentation issues (use spaces, not tabs)
   sudo netplan --debug apply
   ```

2. **Interface naming issues**:
   ```bash
   # List available interfaces
   ip link show
   
   # Update netplan config if eth0 is not the correct interface name
   sudo nano /etc/netplan/01-netcfg.yaml
   ```

3. **DNS resolution problems**:
   ```bash
   # Check if systemd-resolved is running
   sudo systemctl status systemd-resolved
   
   # Update /etc/resolv.conf to use systemd-resolved
   sudo ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
   ```

## Security Considerations

1. **Firewall Rules**: Consider implementing additional iptables rules to restrict inter-VLAN communication
2. **Access Control**: Ensure proper access controls on VLAN configurations
3. **Monitoring**: Implement network monitoring to detect unusual traffic patterns
4. **Updates**: Regularly update the routing script as network topology changes

## Service Assignment Reference

| Service | Internal Network | Internet Network | Database Network | Purpose |
|---------|------------------|------------------|------------------|---------|
| cloudflared | media_center_apps | container_internet | - | Tunnel via normal internet |
| jellyfin | media_center_apps | container_pia_internet | - | Media streaming via VPN |
| jellyseerr | media_center_apps | container_pia_internet | - | Request management via VPN |
| radarr | media_center_apps | container_pia_internet | - | Movie management via VPN |
| sonarr | media_center_apps | container_pia_internet | - | TV management via VPN |
| qbittorrent | media_center_apps | container_pia_internet | - | Torrenting via VPN |
| sabnzbd | media_center_apps | container_pia_internet | - | Usenet downloading via VPN |
| bazarr | media_center_apps | container_pia_internet | - | Subtitle management via VPN |
| readarr | media_center_apps | container_pia_internet | - | Book management via VPN |
| calibre | media_center_apps | - | - | E-book server (internal only) |
| calibre_web | media_center_apps | - | - | E-book web interface (internal only) |
| jellystat | media_center_apps | container_pia_internet | jellystat_db_network | Analytics via VPN + DB access |
| jellystat_db | media_center_apps | container_pia_internet | jellystat_db_network | Database with all networks |

### Network Architecture Summary

- **media_center_apps**: Internal isolated network for inter-service communication (no internet)
- **container_internet**: External network using bridge `br-5b71b45374c1` → VLAN 160 → Normal internet
- **container_pia_internet**: External network using bridge `br-5e100127347a` → VLAN 170 → VPN internet
- **jellystat_db_network**: Isolated database network for jellystat ↔ database communication

This configuration ensures:
1. **Privacy**: Media acquisition services route through VPN
2. **Reliability**: Cloudflared uses direct internet for stable tunnel operation
3. **Security**: Services can communicate internally without internet access
4. **Isolation**: Database traffic is isolated to dedicated network
5. **Flexibility**: External networks allow policy-based routing control 