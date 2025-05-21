# Media Center Stack

This is a comprehensive media center solution that combines various services for managing, downloading, and streaming media content. The stack is containerized using Docker and includes the following services:

## Hardware Requirements

This stack is configured to run on a ROCKCHIP device, utilizing hardware acceleration for improved media transcoding performance. The configuration includes specific device mappings for:
- DRI (Direct Rendering Infrastructure)
- DMA Heap
- Mali GPU
- RGA (Raster Graphic Acceleration)
- MPP (Media Process Platform)

### Tested Environment

This stack has been tested and verified on the following hardware:

**Orange Pi 5 Plus**
- SoC: Rockchip RK3588 8 Core 64 Bit
- Memory: 16GB
- Features: 2.4GHz Frequency, 8K Video Decoding
- Operating System: Armbian Linux 6.1.99-vendor-rk35xx
- Armbian Version: v25.2.3
- Filesystem: ZFS for system and configuration
- Media Storage: NFS mount for media content

```
   _             _    _
   /_\  _ _ _ __ | |__(_)__ _ _ _
  / _ \| '_| '  \| '_ \ / _` | ' \
 /_/ \_\_| |_|_|_|_.__/_\__,_|_||_|
```

The hardware acceleration features have been specifically optimized for this setup, ensuring optimal performance for media transcoding and playback.

## Core Services

### Media Management
- **Jellyfin**: Media streaming server
- **Jellystat**: Analytics and statistics for Jellyfin
- **Jellyseerr**: Request management and discovery for movies and TV shows

### Download Management
- **SABnzbd**: Usenet downloader
- **qBittorrent**: Torrent client
- **Radarr**: Movie collection manager
- **Sonarr**: TV series collection manager
- **Readarr**: Book collection manager
- **Bazarr**: Subtitle management

### E-book Management
- **Calibre**: E-book management server
- **Calibre-Web**: Web interface for e-book library

### Network & Security
- **Cloudflared**: Secure tunnel for remote access

## Features

- Hardware acceleration support for Rockchip devices
- Centralized media storage with volume mapping
- Secure remote access through Cloudflare tunnels
- Automated subtitle downloads
- Integrated request and media management system

## Prerequisites

- Docker and Docker Compose
- Sufficient storage space for media
- Network connectivity
- ROCKCHIP-compatible device for hardware acceleration (currently configured for ROCKCHIP devices)

## Getting Started

1. Clone this repository
2. Set up your environment file:
   ```bash
   # Copy the example environment file
   cp stack.env.example stack.env
   
   # Edit stack.env with your specific configuration
   nano stack.env  # or use your preferred editor
   ```

3. Create your external volumes:
   ```bash
   # Create the required Docker volumes
   docker volume create media_center_media
   docker volume create media_center_config
   docker volume create media_center_temp
   ```

4. Choose your deployment type:

   **Default Setup (External Storage)**:
   ```bash
   docker compose up -d
   ```

   **All Local Storage**:
   ```bash
   docker compose -f docker-compose.yaml -f docker-compose.local-all.yaml up -d
   ```

   **Local Media Only**:
   ```bash
   docker compose -f docker-compose.yaml -f docker-compose.local-media.yaml up -d
   ```

   **Local Config Only**:
   ```bash
   docker compose -f docker-compose.yaml -f docker-compose.local-config.yaml up -d
   ```

   **Local Temp Only**:
   ```bash
   docker compose -f docker-compose.yaml -f docker-compose.local-temp.yaml up -d
   ```

   **Local Media and Config**:
   ```bash
   docker compose -f docker-compose.yaml -f docker-compose.local-media-config.yaml up -d
   ```

   **Local Media and Temp**:
   ```bash
   docker compose -f docker-compose.yaml -f docker-compose.local-media-temp.yaml up -d
   ```

   **Local Config and Temp**:
   ```bash
   docker compose -f docker-compose.yaml -f docker-compose.local-config-temp.yaml up -d
   ```

### Optional Features

The stack includes several optional features that can be enabled in your `stack.env`:

1. **Container Naming**:
   ```bash
   # Default value is "media_center"
   CONTAINER_NAME_PREFIX=media_center
   ```
   Customize the prefix used for all container names in the stack. Containers will be named as `${CONTAINER_NAME_PREFIX}_service_name`.

2. **Media Storage Options**:
   - **Local Storage**:
     ```bash
     ENABLE_EXTERNAL_MEDIA_VOLUME=false
     MEDIA_BASE=/path/to/your/media
     ```
     Uses a local directory for media storage, mounted through Docker volumes.
     Deploy with: `docker compose -f docker-compose.yaml -f docker-compose.local.yaml up -d`
   
   - **External Volume**:
     ```bash
     ENABLE_EXTERNAL_MEDIA_VOLUME=true
     MEDIA_VOLUME_NAME=my_external_volume
     ```
     Uses a pre-existing Docker volume (e.g., NFS mount). The volume must be created before starting the stack.
     Deploy with: `docker compose up -d`

3. **Home IoT Network**: Enable to connect Jellyfin to your home automation network
   ```bash
   ENABLE_HOME_IOT_NETWORK=true
   HOME_IOT_NETWORK=my_home_network
   JELLYFIN_IP=192.168.1.100
   ```

4. **Cloudflare Tunnel**: Enable for secure remote access
   ```bash
   ENABLE_CLOUDFLARED=enabled
   CLOUDFLARED_TOKEN=your_cloudflare_tunnel_token
   ```

These features are disabled by default and can be enabled as needed. See `DEVELOPMENT.md` for detailed information about the configuration structure.

## Storage Architecture

The stack uses a flexible storage approach with multiple deployment options:

### 1. Configuration Storage
- **Purpose**: Service configurations, databases, and application data
- **Deployment Options**:
  - Local storage using bind mounts (via `docker-compose.local-config.yaml`)
  - External Docker volume (default after Jan 1, 2026)
- **Standard Paths**:
  - `/config` for most services
  - `/app/config` or `/app/data` for specific services
- **Environment Variables**:
  - `CONFIG_BASE`: Local storage path
  - `CONFIG_VOLUME_NAME`: External volume name

### 2. Media Storage
- **Purpose**: Movies, TV shows, music, and books
- **Deployment Options**:
  - Local directory (via `docker-compose.local-media.yaml`)
  - External Docker volume (e.g., NFS mount)
- **Access Levels**:
  - Read-only for streaming/management services
  - Read-write for download services
- **Environment Variables**:
  - `MEDIA_BASE`: Local storage path
  - `MEDIA_VOLUME_NAME`: External volume name
  - `CONTAINER_MEDIA_PATH`: Standard mount point
  - `CONTAINER_MEDIA_PATH_LEGACY`: Legacy mount point (compatibility)

### 3. Temporary Storage
- **Purpose**: Cache, downloads, and temporary files
- **Deployment Options**:
  - Local filesystem (via `docker-compose.local-temp.yaml`)
  - External Docker volume
- **Environment Variables**:
  - `TEMP_BASE`: Local storage path
  - `TEMP_VOLUME_NAME`: External volume name

### Storage Combinations
The stack supports various storage combinations through compose files:
- `docker-compose.local-all.yaml`: All storage types use local bind mounts
- `docker-compose.local-media.yaml`: Only media uses local storage
- `docker-compose.local-config.yaml`: Only config uses local storage
- `docker-compose.local-temp.yaml`: Only temp uses local storage
- `docker-compose.local-media-config.yaml`: Media and config use local storage
- `docker-compose.local-media-temp.yaml`: Media and temp use local storage
- `docker-compose.local-config-temp.yaml`: Config and temp use local storage (current default)

This architecture ensures:
- Flexible deployment options for different environments
- Clear separation of storage types
- Easy migration path for future changes
- Backward compatibility during transition

## Network Architecture

The stack uses two Docker networks:
- `media_center_apps`: Internal network for service communication
- `home_iot`: External network for home integration

## Support

For issues and feature requests, please open an issue in the repository.

## Further Tips from Contributors

### GUI Deployment with Portainer (by Gumbee)

For those preferring a more graphical approach to deployment, Portainer is recommended:

1. Install and set up Portainer on your system
2. When adding a new stack in Portainer:
   - Copy the contents of `stack.env.example` into "Environment → Advanced"
   - Update the environment variables as needed
   - Either:
     - Copy and paste the `docker-compose.yml` content directly into the stack
     - Or link Portainer to this repository (or your fork)

This method provides a user-friendly interface for managing your media center stack and its environment variables. 