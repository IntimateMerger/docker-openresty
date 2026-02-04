# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This repository builds and publishes multi-platform Docker images for OpenResty (nginx + LuaJIT) with custom dependencies including OpenSSL 3.4.3 (FIPS-enabled), PCRE2 10.44, and the GeoIP2 module.

**Docker Hub**: `intimatemerger/openresty`
**Platforms**: `linux/amd64`, `linux/arm64`

## Build Commands

### Local Development

```bash
# Build for specific platform (recommended)
# Use linux/arm64 for Apple Silicon, linux/amd64 for Intel/x86_64
docker build --platform=linux/arm64 -t dev-resty:local .

# Build for current platform without specifying (not recommended)
docker build -t dev-resty:local .

# Alternative: Use full repository name
docker build --platform=linux/arm64 -t intimatemerger/openresty:local .

# Build for multiple platforms (requires buildx)
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t dev-resty:local .

# Test the built image
docker run -d -p 80:80 dev-resty:local
```

### Testing Configuration Changes

```bash
# Run with custom nginx.conf
docker run -d -p 80:80 \
  -v $(pwd)/nginx.conf:/usr/local/openresty/nginx/conf/nginx.conf:ro \
  dev-resty:local
```

## Architecture

### Multi-Stage Build Process

The Dockerfile performs a complex multi-stage build in a single RUN command to minimize layer size:

1. **Dependency Installation**: Installs Alpine build dependencies and runtime libraries
2. **OpenSSL Build**: Downloads, patches (for OpenResty compatibility), and compiles OpenSSL 3.4.3 with FIPS support
3. **PCRE2 Build**: Compiles PCRE2 10.44 with JIT support
4. **GeoIP2 Module**: Downloads ngx_http_geoip2_module
5. **OpenResty Build**: Compiles OpenResty with custom configure options linking to the built OpenSSL and PCRE2
6. **Binary Stripping**: Removes debug symbols and unnecessary files to reduce image size
7. **Cleanup**: Removes build dependencies and temporary files

### Key Build Arguments

- `RESTY_VERSION`: OpenResty version (currently 1.27.1.2)
- `RESTY_OPENSSL_VERSION`: OpenSSL version (currently 3.4.3)
- `RESTY_PCRE_VERSION`: PCRE2 version (currently 10.44)
- `RESTY_GEOIP2_VERSION`: GeoIP2 module version (currently 3.4)

### OpenResty Configuration

The build enables the following nginx modules:
- HTTP/2 and HTTP/3 support (`--with-http_v2_module`, `--with-http_v3_module`)
- Dynamic image filter module (`--with-http_image_filter_module=dynamic`)
- Auth request, real IP, gzip static, SSL modules
- GeoIP2 for geographical location detection

LuaJIT is configured with `LUAJIT_NUMMODE=2` (number mode) and Lua 5.2 compatibility.

## CI/CD Pipeline

### GitHub Actions Workflows

The repository uses two separate workflows for improved security and clarity:

#### 1. Build and Push (`.github/workflows/build-and-push.yaml`)

**Triggers**:
- Push to `master`/`main` branch → Build & push to Docker Hub
- Tags matching `*.*.*.*-*` (e.g., `1.27.1.2-0`) → Build & push with version tags
- Manual dispatch → Build & push

**Generated Docker Tags**:
- `latest` - Latest build from main/master
- `1.27.1` - Three-part version (from git tag `1.27.1.2-0`)
- `1.27` - Two-part version

**Required Secrets**:
- `DOCKERHUB_USERNAME` (variable) - Docker Hub username
- `DOCKERHUB_PUSH_TOKEN` (secret) - Docker Hub access token with Read & Write permissions

#### 2. Security Scan (`.github/workflows/security-scan.yaml`)

**Triggers**:
- Pull requests to `master`/`main` branch

**Purpose**:
- Runs Trivy configuration scanner on Dockerfile and workflow files
- Uploads results to GitHub Security tab
- **No Docker Hub access or secrets required** - provides fast security feedback in isolation

### Build Architecture

The build-and-push workflow uses a three-stage process for efficient multi-platform builds:

1. **build** (matrix job):
   - Runs on native runners: `ubuntu-latest` (amd64), `ubuntu-latest-arm` (arm64)
   - Each platform builds independently in parallel
   - Uses digest-based push (`push-by-digest=true`) for reliable multi-arch images
   - Platform-specific cache scopes for optimal cache utilization

2. **merge**:
   - Downloads all platform digests
   - Creates manifest list using `docker buildx imagetools create`
   - Pushes unified multi-platform image with appropriate tags
   - Runs Docker Scout CVE scan on final image

### Security Features

- **Workflow Separation**: Build and security-scan workflows are completely isolated
  - PRs never trigger workflows that access Docker Hub secrets
  - Reduces attack surface for public repository
- **SBOM Generation**: Enabled (`sbom: true`) for all builds to track dependencies
- **Provenance**: Disabled (`provenance: false`) for maximum compatibility with cloud services (ECR, ACR, GCR)
- **Vulnerability Scanning**:
  - Docker Scout (post-merge): Scans final multi-platform image for critical/high CVEs
  - Trivy (PRs only): Scans Dockerfile and configuration, uploads to GitHub Security

### Build Optimization

- **Native Runners**: No QEMU emulation—each platform builds on native architecture for maximum speed
- **Parallel Execution**: Matrix strategy runs amd64 and arm64 builds simultaneously
- **Platform-Specific Caching**: Each architecture maintains separate GitHub Actions cache (`scope=${{ matrix.arch }}`)
- **Digest-Based Merging**: Ensures atomic multi-platform manifest creation
- **Estimated Build Times**:
  - First build (cold cache): 15-30 minutes per platform (parallel)
  - Subsequent builds (warm cache): 5-10 minutes per platform
  - Total wall time: Similar to slowest platform (due to parallelization)

## Version Update Process

When updating OpenResty or dependencies:

1. Update version variables in `Dockerfile`:
   - `RESTY_VERSION` - OpenResty version
   - `RESTY_OPENSSL_VERSION` - OpenSSL version
   - `RESTY_OPENSSL_PATCH_VERSION` - OpenSSL patch version for OpenResty compatibility
   - `RESTY_PCRE_VERSION` and `RESTY_PCRE_SHA256` - PCRE2 version and checksum
   - `RESTY_GEOIP2_VERSION` - GeoIP2 module version

2. Update `README.md` if version tags change

3. Create a feature branch (e.g., `feature-1.27.1.2`) and push

4. After merge to master, tag with version number and revision:
   ```bash
   # Initial release: use -0
   git tag 1.27.1.2-0
   git push origin 1.27.1.2-0

   # Rebuild with same OpenResty version (e.g., OpenSSL update): increment revision
   git tag 1.27.1.2-1
   git push origin 1.27.1.2-1
   ```

### Tagging Strategy

**Git Tags** (with revision number):
- Format: `1.27.1.2-0`, `1.27.1.2-1`, etc.
- Always include revision number for consistency
- Maintains complete build history

**Docker Tags** (generated automatically):
- `1.27.1` - Three-part version (tracks latest patch within 1.27.1.x)
- `1.27` - Two-part version (tracks latest minor)
- `latest` - Latest build from master branch

**Example**: Pushing git tag `1.27.1.2-0` generates Docker tags:
- `intimatemerger/openresty:1.27.1`
- `intimatemerger/openresty:1.27`
- `intimatemerger/openresty:latest`

**Note**: Four-part version tags (e.g., `1.27.1.2`) are not published to Docker Hub. Users should use `1.27.1` to get the latest patch version within the 1.27.1.x series.

## Testing

```bash
# Verify the container starts
docker run --rm dev-resty:local -t

# Check OpenResty version
docker run --rm dev-resty:local -v

# Test HTTP access
docker run -it --rm -p 8080:80 --name dev-resty dev-resty:local
curl http://localhost:8080
```

## Important Notes

- The entire build happens in a single `RUN` command to minimize Docker layer size
- OpenSSL requires OpenResty-specific patches for session callback yielding support
- Binary stripping is performed when `RESTY_STRIP_BINARIES="1"` to reduce image size
- Logs are symlinked to stdout/stderr for Docker-native logging
- Uses `SIGQUIT` instead of `SIGTERM` for graceful shutdown
