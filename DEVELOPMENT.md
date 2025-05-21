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

The stack supports two types of media storage through Docker volumes, configured using separate compose files:

1. **Local Storage (Default)**
   ```bash
   ENABLE_EXTERNAL_MEDIA_VOLUME=false
   MEDIA_BASE=/path/to/your/media
   ```
   Use docker-compose.local.yaml:
   ```yaml
   volumes:
     media_volume:
       driver: local
       driver_opts:
         type: none
         o: bind
         device: ${MEDIA_BASE}
   ```
   Deploy with:
   ```bash
   docker compose -f docker-compose.yaml -f docker-compose.local.yaml up -d
   ```

2. **External Volume**
   ```bash
   ENABLE_EXTERNAL_MEDIA_VOLUME=true
   MEDIA_VOLUME_NAME=my_external_volume
   ```
   Use default docker-compose.yaml:
   ```yaml
   volumes:
     media_volume:
       external: true
       name: ${MEDIA_VOLUME_NAME}
   ```
   Deploy with:
   ```bash
   docker compose up -d
   ```

All services use the same volume configuration regardless of the storage type:
```yaml
volumes:
  - "media_volume:${CONTAINER_MEDIA_PATH}"
  - "media_volume:${CONTAINER_MEDIA_PATH_LEGACY}"
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
   ```