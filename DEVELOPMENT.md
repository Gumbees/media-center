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

The stack uses two types of volume mappings:
1. Configuration volumes: `${SERVICE_CONFIG}:/config`
   - Stores service-specific configuration
   - Persists between container restarts
   - Located in the `CONFIG_BASE` directory

2. Media volumes: `media_center_media:${CONTAINER_MEDIA_PATH}`
   - Shared media storage
   - External Docker volume
   - Accessible to all services

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