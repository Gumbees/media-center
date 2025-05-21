# Development Guide

## Deprecation Notice

The default `docker-compose.yaml` currently maintains backward compatibility by using local config and temp storage. This behavior will be deprecated on January 1, 2026. For new deployments, please use the appropriate `docker-compose.local-*.yaml` files.

### Migration Path
- **Current Setup** (local config/temp): Use `docker-compose.local-config-temp.yaml`
- **All Local Storage**: Use `docker-compose.local-all.yaml`
- **All External Storage**: Use base `docker-compose.yaml` with external volumes
- **Mixed Storage**: Use appropriate `docker-compose.local-*.yaml` files

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
    - "config_volume:/config"  # or /app/config for some services
    - "media_volume:${CONTAINER_MEDIA_PATH}"
  networks:
    - media_center_apps
  restart: unless-stopped
```

## Storage Configuration

The stack supports flexible storage configuration through various compose files:

### Base Configuration
- `docker-compose.yaml`: 
  - **Legacy/Current Behavior**: Defaults to local config and temp storage (until Jan 1, 2026)
  - **Future Behavior**: All volumes will be external
  - **Migration Note**: For current behavior, use `docker-compose.local-config-temp.yaml`

### Local Storage Options

1. **All Local Storage**
   - File: `docker-compose.local-all.yaml`
   - All storage types (media, config, temp) use local bind mounts
   ```bash
   docker compose -f docker-compose.yaml -f docker-compose.local-all.yaml up -d
   ```

2. **Single Local Storage**
   - `docker-compose.local-media.yaml`: Only media uses local storage
   - `docker-compose.local-config.yaml`: Only config uses local storage
   - `docker-compose.local-temp.yaml`: Only temp uses local storage
   ```bash
   # Example: Local media, external config/temp
   docker compose -f docker-compose.yaml -f docker-compose.local-media.yaml up -d
   ```

3. **Dual Local Storage**
   - `docker-compose.local-media-config.yaml`: Media and config use local storage
   - `docker-compose.local-media-temp.yaml`: Media and temp use local storage
   - `docker-compose.local-config-temp.yaml`: Config and temp use local storage (current default behavior)
   ```bash
   # Example: Local media and config, external temp
   docker compose -f docker-compose.yaml -f docker-compose.local-media-config.yaml up -d
   ```

### Storage Types

1. **Media Storage**
   - Primary path: `${CONTAINER_MEDIA_PATH}` (`/media`)
   - Legacy path: `${CONTAINER_MEDIA_PATH_LEGACY}` (`/media-center`)
   - Local path: `${MEDIA_BASE}`
   - External volume: `${MEDIA_VOLUME_NAME}`

2. **Configuration Storage**
   - Standard path: `/config`
   - Special paths: `/app/config`, `/app/data`
   - Local path: `${CONFIG_BASE}`
   - External volume: `${CONFIG_VOLUME_NAME}`

3. **Temporary Storage**
   - Paths: `/temp`, `/cache`, `/downloads`
   - Local path: `${TEMP_BASE}`
   - External volume: `${TEMP_VOLUME_NAME}`

### Pipeline Integration

Each compose file is self-contained and can be used independently in pipelines:

```yaml
# GitLab CI example
stages:
  - deploy

deploy_media:
  stage: deploy
  script:
    - docker compose -f docker-compose.local-media.yaml up -d

deploy_config:
  stage: deploy
  script:
    - docker compose -f docker-compose.local-config.yaml up -d

deploy_temp:
  stage: deploy
  script:
    - docker compose -f docker-compose.local-temp.yaml up -d

deploy_all_local:
  stage: deploy
  script:
    - docker compose -f docker-compose.local-all.yaml up -d
```

### Common Deployment Scenarios

1. **Legacy/Current Setup (until Jan 1, 2026)**
   ```bash
   # Local config and temp (current default)
   docker compose up -d
   # OR explicitly with the same behavior
   docker compose -f docker-compose.yaml -f docker-compose.local-config-temp.yaml up -d
   ```

2. **New Deployments (Recommended)**
   ```bash
   # All local storage
   docker compose -f docker-compose.yaml -f docker-compose.local-all.yaml up -d

   # All external storage
   docker compose -f docker-compose.yaml up -d  # After Jan 1, 2026

   # Mixed storage (example: local config/temp, external media)
   docker compose -f docker-compose.yaml -f docker-compose.local-config-temp.yaml up -d
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