# ROS2 CUDA Multi-Platform CI

Система автоматической сборки Docker-образов с ROS2 Humble и CUDA.

## Целевые платформы

- x86_64 с NVIDIA GPU;
- Jetson AGX Orin 64GB — JetPack 6.2.2, L4T 36.5;
- Jetson Orin Nano — JetPack 7.2, L4T 39.2.

## Способы сборки

- x86_64 в GitHub Actions;
- ARM64 через Docker Buildx и QEMU;
- ARM64 нативно на self-hosted Jetson-раннерах.

## Registry

Готовые образы публикуются в GitHub Container Registry (GHCR).
