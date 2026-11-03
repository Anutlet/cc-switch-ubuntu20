# 在 Ubuntu 20.04 上运行 CC Switch AppImage

[English](README.md) | 简体中文

使用独立的 Ubuntu 22.04 运行库启动官方 Linux AppImage。本项目不会安装或替换系统 glibc，也不分发 CC Switch 或 Ubuntu 软件包。

## 环境要求

- Ubuntu 20.04 x86_64
- `unsquashfs`、`dpkg-deb`、`patchelf` 和 Bash
- 官方 `CC-Switch-vVERSION-Linux-x86_64.AppImage`（已在 4.0.21 和 4.0.25 上测试）
- Ubuntu 22.04 amd64 软件包：`libc6` 2.35-0ubuntu3.15、`libfreetype6` 2.11.1+dfsg-1ubuntu0.4、`libgbm1` 23.2.1-1ubuntu3.1~22.04.4

请自行从官方渠道下载上述四个文件。三个 `.deb` 文件只供脚本解压使用，**不要**通过 `dpkg -i` 安装到系统中。

## 安装

```bash
./install.sh \
  /path/to/CC-Switch-v4.0.25-Linux-x86_64.AppImage \
  /path/to/libc6_2.35-0ubuntu3.15_amd64.deb \
  /path/to/libfreetype6_2.11.1+dfsg-1ubuntu0.4_amd64.deb \
  /path/to/libgbm1_23.2.1-1ubuntu3.1~22.04.4_amd64.deb
```

安装后可从应用菜单启动 **CC Switch**，也可运行 `~/.local/bin/cc-switch-appimage-local`。启动日志写入 `~/.cache/cc-switch-launch.log`。

安装脚本将 AppImage 解压到 `~/.local/share/cc-switch-VERSION-local`，通过独立的 glibc 加载器运行原版 `cc-switch`，并为两个 WebKit 子进程使用相同的加载器。启动时工作目录设为解压目录中的 `usr`，因为这个 WebKit 构建版本会相对该目录查找子进程。

应用内更新器会用下载的 AppImage 覆盖当前运行的可执行文件。在此适配方案中，该文件是 glibc 加载器。启动脚本现在每次都使用独立的加载器副本，避免更新破坏已安装的加载器。应用内更新后，请从应用菜单重新启动；下载的 AppImage 会保存为 `~/.cache/cc-switch-updater-*.AppImage`。将它重命名为 `CC-Switch-vVERSION-Linux-x86_64.AppImage` 格式，再运行 `install.sh`，即可切换到新版本。

此方案已在一台 Ubuntu 20.04 工作站上验证。它依赖上述软件包版本；其他 AppImage 版本可能需要进一步适配。

## 早期源码构建尝试

[`experimental/source-build`](experimental/source-build) 保存了早期尝试使用 Docker 和 Flatpak 构建的文件，包括对上游源码的集成补丁。该方案尚未完成验证；上面的 AppImage 安装脚本是目前可用的方案。这些文件需要复制到匹配版本的 CC Switch 源码目录后才能使用。
