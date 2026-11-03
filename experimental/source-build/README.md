# Earlier Docker and Flatpak build attempt

This directory contains the Ubuntu 22.04 container and Flatpak build files formerly added to the CC Switch source checkout. This path was abandoned after the Docker image download proved too slow. It has not produced a verified build.

To resume the work, copy `.dockerignore`, `UBUNTU_20.04_INSTALLATION.md`, and `scripts/` to the root of a matching CC Switch checkout, then apply `upstream-integration.patch` there. Review and fix the scripts before running them; their paths and version references target the earlier 4.0.21 checkout. In particular, the Flatpak smoke command references an artifact filename that differs from the generated filename.
