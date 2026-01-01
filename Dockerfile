# syntax=docker/dockerfile:1
FROM python:3.12-slim

# 1. 环境配置：消除警告，定义路径，开启 UV 系统模式
ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONDONTWRITEBYTECODE=1 \
    PLAYWRIGHT_BROWSERS_PATH=/ms-playwright \
    UV_SYSTEM_PYTHON=1 \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    # 增加 APT 容错，防止 GHA 网络抖动
    APT_OPTS="-o Acquire::Retries=3 -o Acquire::http::Timeout=20"

# 2. 引入 uv
COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv

# 3. 核心加速器 & 基础配置层
# 这一层安装 eatmydata 并配置 dpkg，为后续巨型安装铺路
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    apt-get update $APT_OPTS && \
    apt-get install -y --no-install-recommends eatmydata && \
    # 配置 DPKG 排除文档 (极简)
    echo 'path-exclude /usr/share/doc/*' > /etc/dpkg/dpkg.cfg.d/docker-clean && \
    echo 'path-exclude /usr/share/man/*' >> /etc/dpkg/dpkg.cfg.d/docker-clean && \
    echo 'path-exclude /usr/share/groff/*' >> /etc/dpkg/dpkg.cfg.d/docker-clean && \
    echo 'path-exclude /usr/share/info/*' >> /etc/dpkg/dpkg.cfg.d/docker-clean && \
    # 禁用 man-db 触发器
    echo "set man-db/auto-update false" | debconf-communicate && \
    # 关键：由于 mount 导致 list 存在，但为了减小此层体积，我们不保留 list，
    # 下一层 update 会很快（因为 cache mount 还在）
    rm -rf /var/lib/apt/lists/*

# 4. TeXLive & 系统依赖层 (最耗时层 - 极致缓存)
# 使用 eatmydata 包裹 apt-get，解压速度提升数倍
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    apt-get update $APT_OPTS && \
    # 核心魔法：eatmydata 拦截 fsync
    eatmydata apt-get install -y --no-install-recommends $APT_OPTS \
        git curl perl make ca-certificates fontconfig \
        fonts-noto-cjk fonts-noto-cjk-extra \
        texlive latexmk texlive-latex-base texlive-latex-recommended \
        texlive-latex-extra texlive-luatex texlive-fonts-recommended \
        texlive-fonts-extra texlive-lang-cjk texlive-lang-chinese \
        texlive-lang-japanese texlive-plain-generic texlive-science && \
    rm -rf /var/lib/apt/lists/*

# 5. Playwright 层 (变动频率中等)
# 分离是为了防止 Playwright 更新导致 TeXLive 重装
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    --mount=type=cache,target=/root/.cache/uv \
    # 1. 安装 python 包
    uv pip install playwright && \
    # 2. 安装系统依赖 (利用 eatmydata 加速)
    apt-get update $APT_OPTS && \
    eatmydata playwright install-deps chromium && \
    # 3. 下载浏览器二进制
    playwright install chromium && \
    # 4. 刷新字体 & 清理
    fc-cache -fv && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

# 6. Python 依赖层 (变动频率高)
COPY requirements.txt .
RUN --mount=type=cache,target=/root/.cache/uv \
    uv pip install -r requirements.txt

# 7. 应用代码层
COPY exporter/ /app/exporter/
COPY export-pdf.sh /usr/local/bin/export-pdf
RUN chmod +x /usr/local/bin/export-pdf

CMD ["/usr/local/bin/export-pdf"]