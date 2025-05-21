# Development Guide

## Deprecation Notice

The default `docker-compose.yaml` currently maintains backward compatibility by using local config and temp storage. This behavior will be deprecated on January 1, 2026. For new deployments, please use the appropriate `docker-compose.local-*.yaml` files.

### Migration Path
- **Current Setup** (local config/temp): Use `docker-compose.local-config-temp.yaml`
- **All Local Storage**: Use `docker-compose.local-all.yaml`
- **All External Storage**: Use base `docker-compose.yaml` with external volumes
- **Mixed Storage**: Use appropriate `docker-compose.local-*.yaml` files

## Docker Compose Structure

The `docker-compose.yaml` file is organized into several sections and uses external volumes by default. For local storage options, use the appropriate override files.

### Service Definition Pattern

Each service follows this general pattern:
```yaml
service_name:
  container_name: "${CONTAINER_NAME_PREFIX}_service_name"
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

The stack uses external volumes by default and supports flexible storage configuration through Docker Compose overrides:

### Base Configuration
- `docker-compose.yaml`: Uses external volumes for all storage (media, config, and temp)

### Volume Override Files

Each override file defines specific local volume configurations:

1. **Single Volume Overrides**
   - `docker-compose.local-media.yaml`: Local media volume
   - `docker-compose.local-config.yaml`: Local config volume
   - `docker-compose.local-temp.yaml`: Local temp volume

2. **Multi-Volume Overrides**
   - `docker-compose.local-media-config.yaml`: Local media and config volumes
   - `docker-compose.local-media-temp.yaml`: Local media and temp volumes
   - `docker-compose.local-config-temp.yaml`: Local config and temp volumes
   - `docker-compose.local-all.yaml`: All volumes use local storage

### Usage Examples

1. **Default Setup (External Storage)**
   ```bash
   # All volumes are external
   docker compose up -d
   ```

2. **All Local Storage**
   ```bash
   # Override all volumes to use local storage
   docker compose -f docker-compose.yaml -f docker-compose.local-all.yaml up -d
   ```

3. **Mixed Storage**
   ```bash
   # Example: Local media, external config/temp
   docker compose -f docker-compose.yaml -f docker-compose.local-media.yaml up -d

   # Example: Local media and config, external temp
   docker compose -f docker-compose.yaml -f docker-compose.local-media-config.yaml up -d
   ```

### Storage Types

1. **Media Storage**
   - Primary path: `${CONTAINER_MEDIA_PATH}` (`/media`)
   - Legacy path: `${CONTAINER_MEDIA_PATH_LEGACY}` (`/media-center`)
   - Local path: `${MEDIA_BASE}` (when using local storage)
   - External volume: `${MEDIA_VOLUME_NAME}`

2. **Configuration Storage**
   - Standard path: `/config`
   - Special paths: `/app/config`, `/app/data`
   - Local path: `${CONFIG_BASE}` (when using local storage)
   - External volume: `${CONFIG_VOLUME_NAME}`

3. **Temporary Storage**
   - Paths: `/temp`, `/cache`, `/downloads`
   - Local path: `${TEMP_BASE}` (when using local storage)
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

### Container Naming
```bash
CONTAINER_NAME_PREFIX=media_center
```
- Defines the prefix used for all container names
- Default value is "media_center"
- Container names will be formatted as `${CONTAINER_NAME_PREFIX}_service_name`

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