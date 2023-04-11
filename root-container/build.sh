#! /bin/bash

# Build Dockerfile for ARM64 architecture
docker buildx build --platform linux/arm64 -t myimage:latest .