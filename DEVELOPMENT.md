# Development Guide

This document explains the structure and configuration of the Media Center stack.

## Docker Compose Structure

The `docker-compose.yaml` file is organized into several sections:

### Service Definition Pattern

Each service follows this general pattern:
```yaml
service_name:
  container_name: "service_name"
  image: "image_source:tag"
  env_file:
    - stack.env
  environment:
    - PUID=${PUID}
    - PGID=${PGID}
    - TZ=${TZ}
    # Service-specific environment variables
  volumes:
    - "${SERVICE_CONFIG}:/config"
    - "media_center_media:${CONTAINER_MEDIA_PATH}"
  networks:
    - media_center_apps
  restart: unless-stopped
```

### Volume Mapping

The stack supports two types of media storage:

1. **Local Storage (Default)**
   ```bash
   ENABLE_EXTERNAL_MEDIA_VOLUME=false
   MEDIA_BASE=/data/media  # Local path for media storage
   ```
   - Uses bind mounts to map local directories
   - Follows the same pattern as config directories
   - Recommended for single-node deployments

2. **External Volume (Optional)**
   ```bash
   ENABLE_EXTERNAL_MEDIA_VOLUME=true
   MEDIA_VOLUME_NAME=media_center_media
   ```
   - Uses Docker named volumes
   - Supports NFS mounts and shared storage
   - Recommended for multi-node deployments

The volume mapping is automatically handled in docker-compose.yaml based on the `ENABLE_EXTERNAL_MEDIA_VOLUME` setting:
```yaml
volumes:
  - ${ENABLE_EXTERNAL_MEDIA_VOLUME:-false} && "${MEDIA_VOLUME_NAME}:${CONTAINER_MEDIA_PATH}" || "${MEDIA_BASE}:${CONTAINER_MEDIA_PATH}"
```

### Base Paths
```bash
CONFIG_BASE=/data/media_center  # Configuration storage
TEMP_BASE=/temp/media_center    # Temporary files
MEDIA_BASE=/data/media         # Media storage (when not using external volume)
```
- All paths follow a consistent structure
- Each service has its dedicated config directory
- Media storage location depends on volume configuration

## Environment File Structure

The `stack.env` file is organized into sections:

### Base Paths
```bash
CONFIG_BASE=/data/media_center
TEMP_BASE=/temp/media_center
```
- `CONFIG_BASE`: Root directory for service configurations
- `TEMP_BASE`: Root directory for temporary files

### Media Storage
```bash
MEDIA_VOLUME_NAME=media_center_media
CONTAINER_MEDIA_PATH=/media
CONTAINER_MEDIA_PATH_LEGACY=/media-center
```
- Defines the media volume name and mount points
- Includes legacy path for compatibility

### System Configuration
```bash
PUID=911
PGID=911
TZ=America/New_York
ARCH=arm64v8
```
- User/group IDs for container permissions
- Timezone setting
- Architecture specification

### Service Paths
```bash
SERVICE_CONFIG=${CONFIG_BASE}/service-name
SERVICE_TEMP=${TEMP_BASE}/service-name
```
- Each service has its configuration path
- Some services have additional temporary storage paths

### Network Configuration
```bash
MEDIA_CENTER_NETWORK=media_center_apps
HOME_IOT_NETWORK=home
```
- Defines Docker networks
- Includes both internal and external networks

### Security Best Practices

1. **Environment File Management**
   - Never commit `stack.env` to version control
   - Use `stack.env.example` as a template
   - Keep sensitive data offline or in a key vault
   - The `.gitignore` file is configured to exclude `stack.env`

2. **Sensitive Data Handling**
   - API tokens
   - Network configurations
   - Service credentials
   - Device-specific paths

## Adding New Services

To add a new service:

1. Add service definition to `docker-compose.yaml`:
   - Follow the standard pattern
   - Include necessary environment variables
   - Configure appropriate volume mappings

2. Add configuration paths to `stack.env`:
   ```bash
   NEW_SERVICE_CONFIG=${CONFIG_BASE}/new-service
   NEW_SERVICE_TEMP=${TEMP_BASE}/new-service  # if needed
   ```

3. Create necessary directories:
   ```bash
   mkdir -p ${CONFIG_BASE}/new-service
   mkdir -p ${TEMP_BASE}/new-service  # if needed
   ```

4. Set appropriate permissions:
   ```bash
   chown -R ${PUID}:${PGID} ${CONFIG_BASE}/new-service
   ```

## Best Practices

1. **Environment Variables**
   - Use descriptive names
   - Group related variables
   - Document any special requirements

2. **Volume Management**
   - Use named volumes for shared storage
   - Use bind mounts for configuration
   - Keep temporary files in `TEMP_BASE`

3. **Network Configuration**
   - Use internal network for service communication
   - Expose ports only when necessary
   - Use external network for specific integrations

4. **Security**
   - Never commit sensitive data to version control
   - Use environment variables for secrets
   - Follow principle of least privilege

## Troubleshooting

1. Check container logs:
   ```bash
   docker-compose logs service-name
   ```

2. Verify volume permissions:
   ```bash
   ls -l ${CONFIG_BASE}/service-name
   ```

3. Validate network connectivity:
   ```bash
   docker network inspect media_center_apps
   ```

## Hardware Acceleration

This stack is configured for ROCKCHIP devices and includes specific hardware acceleration mappings. When developing or modifying the stack, be aware of:

- Device mappings in the `docker-compose.yaml`
- Hardware-specific environment variables in `stack.env`
- The `ENABLE_ROCKCHIP_ACCELERATION` toggle

## Optional Features

### External Volumes and Networks

The stack supports optional external volumes and networks through environment variables:

1. **External Media Volume**
   ```bash
   # In stack.env
   ENABLE_EXTERNAL_MEDIA_VOLUME=true
   MEDIA_VOLUME_NAME=my_external_media
   ```
   - When enabled, uses an existing Docker volume for media storage
   - When disabled, creates a local volume automatically
   - Useful for NFS mounts or shared storage solutions

2. **Home IoT Network**
   ```bash
   # In stack.env
   ENABLE_HOME_IOT_NETWORK=true
   HOME_IOT_NETWORK=my_home_network
   JELLYFIN_IP=192.168.1.100
   ```
   - When enabled, connects Jellyfin to an external network
   - When disabled, only uses internal media_center_apps network
   - Useful for home automation integration

### Default Behavior

- If `ENABLE_EXTERNAL_MEDIA_VOLUME` is not set, defaults to `false`
- If `ENABLE_HOME_IOT_NETWORK` is not set, defaults to `false`
- Network and volume names have default values if not specified
- All optional features can be enabled/disabled without modifying docker-compose.yaml 