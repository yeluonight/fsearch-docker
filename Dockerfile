# 使用 Ubuntu 作为基础镜像
FROM ubuntu:22.04

# 避免安装过程中的交互
ENV DEBIAN_FRONTEND=noninteractive

# 设置默认语言环境
ENV LANG=zh_CN.UTF-8
ENV LANGUAGE=zh_CN:zh
ENV LC_ALL=zh_CN.UTF-8

# 安装必要的依赖
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
    x11vnc \
    xvfb \
    fluxbox \
    wget \
    supervisor \
    net-tools \
    novnc \
    gettext \
    valac \
    python3 \
    python3-pip \
    websockify \
    locales \
    language-pack-zh-hans \
    fonts-noto-cjk \
    fonts-noto-cjk-extra \
    && rm -rf /var/lib/apt/lists/*
    
# 配置 Fluxbox
RUN mkdir -p /root/.fluxbox && \
    echo 'session.screen0.workspaceNames: Workspace 1\n\
session.screen0.toolbar.visible: false\n\
session.screen0.toolbar.autoHide: true\n\
session.screen0.defaultDeco: NONE\n\
session.screen0.windowPlacement: CenterPlacement\n\
session.screen0.focusModel: ClickFocus\n\
session.screen0.fullMaximization: false\n\
session.screen0.maxIgnoreIncrement: true\n\
session.screen0.workspacewarping: false\n\
session.screen0.showwindowposition: true\n\
session.screen0.maxDisableMove: true\n\
session.screen0.maxDisableResize: true\n\
session.screen0.colPlacementDirection: TopToBottom\n\
session.screen0.rowPlacementDirection: LeftToRight\n\
session.screen0.focusNewWindows: true\n\
session.menuFile: /root/.fluxbox/menu\n\
session.keyFile: /root/.fluxbox/keys\n\
session.styleFile: /usr/share/fluxbox/styles/Natura\n\
session.configVersion: 13' > /root/.fluxbox/init
    
# 生成和设置本地化
RUN locale-gen zh_CN.UTF-8 && \
    update-locale LANG=zh_CN.UTF-8 LANGUAGE=zh_CN:zh LC_ALL=zh_CN.UTF-8

# 克隆和编译 fsearch
RUN git clone https://github.com/cboxdoerfer/fsearch.git /fsearch && \
    cd /fsearch && \
    git fetch --tags && \
    latestTag=$(git describe --tags `git rev-list --tags --max-count=1`) && \
    git checkout $latestTag && \
    meson setup build \
        -Dprefix=/usr/local \
        -Dbuildtype=release && \
    cd build && \
    ninja -v && \
    ninja install

# 设置 noVNC
RUN mkdir -p /usr/share/novnc && \
    ln -sf /usr/share/novnc/vnc.html /usr/share/novnc/index.html && \
    chmod -R a+rx /usr/share/novnc && \
    mkdir -p /var/log/supervisor && \
    mv /usr/share/novnc/vnc.html /usr/share/novnc/vnc_original.html && \
    echo '<!DOCTYPE html><html><head>\
    <meta charset="UTF-8">\
    <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">\
    <title>FSearch</title>\
    <script>\
    window.onload = function() {\
        window.location.replace("vnc_original.html?autoconnect=true&resize=scale&quality=9&compression=0&view_only=false&reconnect=true&show_dot=true&fullscreen=true");\
    };\
    </script>\
    </head><body></body></html>' > /usr/share/novnc/vnc.html && \
    ln -sf /usr/share/novnc/vnc.html /usr/share/novnc/index.html

# 复制 supervisor 配置文件
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# 设置环境变量
ENV DISPLAY=:1
ENV GTK_IM_MODULE=fcitx
ENV QT_IM_MODULE=fcitx
ENV XMODIFIERS=@im=fcitx
ENV HOME=/root

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
