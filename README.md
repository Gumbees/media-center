# Media Center Stack

This is a comprehensive media center solution that combines various services for managing, downloading, and streaming media content. The stack is containerized using Docker and includes the following services:

## Hardware Requirements

This stack is configured to run on a ROCKCHIP device, utilizing hardware acceleration for improved media transcoding performance. The configuration includes specific device mappings for:
- DRI (Direct Rendering Infrastructure)
- DMA Heap
- Mali GPU
- RGA (Raster Graphic Acceleration)
- MPP (Media Process Platform)

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
   - **IMPORTANT**: Never commit your `stack.env` file to version control
   - The `stack.env` file contains sensitive information and should be kept offline
   - Consider using a key vault service for production deployments
   - By default, `stack.env` is ignored in `.gitignore`
   - Review all settings in `stack.env`, particularly:
     - Network configurations (IPs and domain names)
     - User/Group IDs (PUID/PGID)
     - Media storage paths
     - Cloudflare tunnel token
3. Create required directories specified in the environment file
4. Run `docker-compose up -d` to start the stack

## Security Considerations

- The `stack.env` file contains sensitive information such as:
  - API tokens
  - Network configurations
  - Service credentials
- Never commit the actual `stack.env` file to public repositories
- Use `stack.env.example` as a template, which contains no sensitive data
- Consider using a key vault service for production deployments
- The repository includes a `.gitignore` file to prevent accidental commits of sensitive files

## Configuration

The stack is configured through two main files:
- `docker-compose.yaml`: Service definitions and container configurations
- `stack.env`: Environment variables and path configurations

### Optional Features

The stack includes several optional features that can be enabled in your `stack.env`:

1. **Media Storage Options**:
   - **Local Storage (Default)**:
     ```bash
     ENABLE_EXTERNAL_MEDIA_VOLUME=false
     MEDIA_BASE=/data/media
     ```
   - **External Volume**:
     ```bash
     ENABLE_EXTERNAL_MEDIA_VOLUME=true
     MEDIA_VOLUME_NAME=my_external_media
     ```

2. **Home IoT Network**: Enable to connect Jellyfin to your home automation network
   ```bash
   ENABLE_HOME_IOT_NETWORK=true
   HOME_IOT_NETWORK=my_home_network
   JELLYFIN_IP=192.168.1.100
   ```

These features are disabled by default and can be enabled as needed. The media storage defaults to using local bind mounts, which is recommended for single-node deployments. External volumes are recommended for multi-node setups or when using NFS mounts.

See `DEVELOPMENT.md` for detailed information about the configuration structure.

## Network Architecture

The stack uses two Docker networks:
- `media_center_apps`: Internal network for service communication
- `home_iot`: External network for home integration

## Support

For issues and feature requests, please open an issue in the repository. 