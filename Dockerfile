# 第一阶段：构建环境
FROM ubuntu:22.04 AS builder

ENV DEBIAN_FRONTEND=noninteractive

# 安装编译依赖
RUN apt-get update && apt-get install -y \
    build-essential \
    meson \
    ninja-build \
    pkg-config \
    libglib2.0-dev \
    libgtk-3-dev \
    libpcre2-dev \
    libicu-dev \
    git \
    gettext \
    valac \
    && rm -rf /var/lib/apt/lists/*

# 编译 fsearch
RUN git clone https://github.com/cboxdoerfer/fsearch.git /fsearch && \
    cd /fsearch && \
    git fetch --tags && \
    latestTag=$(git describe --tags `git rev-list --tags --max-count=1`) && \
    git checkout $latestTag && \
    meson setup build \
        -Dprefix=/usr \
        -Dbuildtype=release && \
    cd build && \
    ninja -v && \
    DESTDIR=/app ninja install

# 第二阶段：运行环境
FROM ubuntu:22.04

# 设置环境变量
ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=zh_CN.UTF-8
ENV LANGUAGE=zh_CN:zh
ENV LC_ALL=zh_CN.UTF-8
ENV DISPLAY=:1
ENV GTK_IM_MODULE=fcitx
ENV QT_IM_MODULE=fcitx
ENV XMODIFIERS=@im=fcitx
ENV HOME=/root

# 安装运行时依赖
RUN apt-get update && apt-get install -y \
    libglib2.0-0 \
    libgtk-3-0 \
    libpcre2-8-0 \
    libicu70 \
    x11vnc \
    xvfb \
    fluxbox \
    supervisor \
    novnc \
    websockify \
    locales \
    language-pack-zh-hans \
    fonts-noto-cjk \
    --no-install-recommends && \
    rm -rf /var/lib/apt/lists/* && \
    locale-gen zh_CN.UTF-8 && \
    update-locale LANG=zh_CN.UTF-8 LANGUAGE=zh_CN:zh LC_ALL=zh_CN.UTF-8

# 从构建阶段复制编译好的 fsearch
COPY --from=builder /app/usr /usr/

# 配置 Fluxbox
RUN mkdir -p /root/.fluxbox && \
    echo 'session.screen0.workspaceNames: Workspace 1\n\
session.screen0.toolbar.visible: false\n\
session.screen0.toolbar.autoHide: true\n\
session.screen0.defaultDeco: NORMAL\n\
session.screen0.windowPlacement: CenterPlacement\n\
session.screen0.focusModel: ClickFocus\n\
session.screen0.fullMaximization: true\n\
session.screen0.maxIgnoreIncrement: true\n\
session.screen0.workspacewarping: false\n\
session.screen0.showwindowposition: true\n\
session.screen0.maxDisableMove: false\n\
session.screen0.maxDisableResize: false\n\
session.screen0.colPlacementDirection: TopToBottom\n\
session.screen0.rowPlacementDirection: LeftToRight\n\
session.screen0.focusNewWindows: true\n\
session.menuFile: /root/.fluxbox/menu\n\
session.keyFile: /root/.fluxbox/keys\n\
session.styleFile: /usr/share/fluxbox/styles/Natura\n\
session.configVersion: 13' > /root/.fluxbox/init

# 设置 noVNC
RUN mkdir -p /usr/share/novnc && \
    ln -sf /usr/share/novnc/vnc.html /usr/share/novnc/index.html && \
    chmod -R a+rx /usr/share/novnc && \
    mkdir -p /var/log/supervisor && \
    mv /usr/share/novnc/vnc.html /usr/share/novnc/vnc_original.html && \
    echo '<!DOCTYPE html><html><head>\
    <meta charset="UTF-8">\
    <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=yes">\
    <title>FSearch</title>\
    <script>\
    window.onload = function() {\
        window.location.replace("vnc_original.html?autoconnect=true&resize=remote&quality=9&compression=0&view_only=false&reconnect=true&show_dot=true&fullscreen=false");\
    };\
    </script>\
    </head><body></body></html>' > /usr/share/novnc/vnc.html && \
    ln -sf /usr/share/novnc/vnc.html /usr/share/novnc/index.html

# 复制 supervisor 配置文件
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# 暴露端口
EXPOSE 8080 5900

# 设置工作目录
WORKDIR /root

# 创建启动脚本
RUN echo '#!/bin/bash\n\
    mkdir -p /var/run\n\
    exec /usr/bin/supervisord -n -c /etc/supervisor/conf.d/supervisord.conf' > /start.sh && \
    chmod +x /start.sh

# 启动服务
CMD ["/start.sh"]
