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

## 实现原理

Ubuntu 20.04 自带 glibc 2.31，而已测试的官方 AppImage 需要较新 glibc 的符号，因此直接运行会在应用启动前报错。本脚本保留官方应用二进制，将所需运行库放在用户主目录中：

1. 读取 AppImage 中 SquashFS 的偏移量，将内容解压到 `~/.local/share/cc-switch-VERSION-local/squashfs-root`。
2. 将指定的 Ubuntu 22.04 `.deb` 分别解压到独立的 `glibc`、`freetype` 和 `gbm` 目录。另将宿主机的 `libstdc++.so.6` 复制到 `compat`，移除该副本的 RPATH。脚本会检查软件包名称、版本和架构，但不会校验下载文件的哈希值。
3. 启动脚本通过独立的 `ld-linux-x86-64.so.2` 运行程序，并指定这些目录及 AppImage 自带库的搜索路径。系统 glibc 不会被修改；应用仍会使用宿主机服务以及此方案未提供的其他库。
4. WebKit 会单独启动网页和网络子进程。安装脚本为这两个入口创建包装脚本，让它们也使用独立的加载器，否则它们会使用宿主机 glibc。启动脚本还加载 AppImage 的 GTK 环境设置，并将工作目录设为解压目录中的 `usr`，因为这个 WebKit 构建版本会相对该目录查找子进程。
5. 生成 `~/.local/bin/cc-switch-appimage-local` 和 `~/.local/share/applications/cc-switch.desktop`，供应用菜单启动。本仓库不保存 CC Switch 的配置或供应商数据。

### 应用内更新

应用内更新器会用下载的 AppImage 覆盖当前运行的可执行文件。在此适配方案中，该文件是 glibc 加载器。启动脚本现在每次都使用独立的加载器副本，避免更新破坏已安装的加载器。应用内更新后，请从应用菜单重新启动；下载的 AppImage 会保存为 `~/.cache/cc-switch-updater-*.AppImage`。将它重命名为 `CC-Switch-vVERSION-Linux-x86_64.AppImage` 格式，再运行 `install.sh`，即可切换到新版本。

更新器立即重启时可能会失败，因为它会绕过这个兼容启动脚本。再次从应用菜单启动时仍运行先前安装的版本，直到使用新 AppImage 重新运行 `install.sh`。

## 与上游 Flatpak 构建方案的区别

[上游 Flatpak 清单](https://github.com/farion1231/cc-switch/blob/main/flatpak/com.ccswitch.desktop.yml) 将 CC Switch 的 `.deb` 打包到 GNOME 46 Flatpak 运行环境中。它同样不替换宿主机 glibc，但通过 Flatpak 提供运行环境，而非解压独立的 Ubuntu `.deb` 软件包。

| 对比项 | 本项目的 AppImage 适配方案 | 上游 Flatpak 构建方案 |
| --- | --- | --- |
| 应用文件 | 解压官方 AppImage，无须编译 CC Switch 源码 | 将编译生成的 CC Switch `.deb` 打包为 Flatpak |
| 运行库 | 独立的 Ubuntu 22.04 glibc、选定依赖库及 AppImage 自带库 | `org.gnome.Platform//46` 及 Flatpak 内打包的库 |
| 安装方式 | 用户目录中的文件和桌面入口，无须安装 Flatpak 运行环境 | 需要 Flatpak 和 GNOME 运行环境 |
| 文件访问 | 以当前用户身份运行，没有 Flatpak 沙箱 | 在 Flatpak 沙箱内运行；目前上游清单授予整个主目录的访问权限 |
| 更新方式 | 每个新 AppImage 需用本脚本解压安装；应用内更新还需执行上述手动步骤 | 从支持更新的远程仓库安装时可由 Flatpak 管理更新；独立 `.flatpak` 文件需要重新安装新版本 |

两种方案都不修改系统 glibc。Flatpak 提供明确的运行环境和权限模型；本方案沿用官方 AppImage 的打包内容，依赖所选运行库与宿主系统兼容。当前只在一台 Ubuntu 20.04 工作站上验证过 CC Switch 4.0.21 和 4.0.25，其他版本可能需要调整。
