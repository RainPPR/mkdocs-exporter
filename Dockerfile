# syntax=docker/dockerfile:1
FROM python:3.12-slim

# 1. 环境配置
ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONDONTWRITEBYTECODE=1 \
    PLAYWRIGHT_BROWSERS_PATH=/ms-playwright \
    UV_SYSTEM_PYTHON=1 \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    APT_OPTS="-o Acquire::Retries=3 -o Acquire::http::Timeout=20"

# 2. 引入 uv
COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv

# 3. 基础配置层 (配置 dpkg 排除、安装 eatmydata)
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    apt-get update $APT_OPTS && \
    apt-get install -y --no-install-recommends eatmydata && \
    # 配置 DPKG 排除 (阻断垃圾文件写入磁盘)
    echo 'path-exclude /usr/share/doc/*' > /etc/dpkg/dpkg.cfg.d/docker-clean && \
    echo 'path-exclude /usr/share/man/*' >> /etc/dpkg/dpkg.cfg.d/docker-clean && \
    echo 'path-exclude /usr/share/groff/*' >> /etc/dpkg/dpkg.cfg.d/docker-clean && \
    echo 'path-exclude /usr/share/info/*' >> /etc/dpkg/dpkg.cfg.d/docker-clean && \
    echo 'path-exclude /usr/share/lintian/*' >> /etc/dpkg/dpkg.cfg.d/docker-clean && \
    echo 'path-exclude /usr/share/linda/*' >> /etc/dpkg/dpkg.cfg.d/docker-clean && \
    echo 'path-exclude /usr/share/locale/*' >> /etc/dpkg/dpkg.cfg.d/docker-clean && \
    # 既然我们要极致空间，这里不留 lists
    rm -rf /var/lib/apt/lists/*

# 4. TeXLive & 系统依赖层 (硬核优化版)
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    apt-get update $APT_OPTS && \
    # A. 安装包，但严禁运行触发器 (节约大量时间)
    eatmydata apt-get install -y --no-install-recommends \
        -o Dpkg::Options::="--no-triggers" \
        $APT_OPTS \
        git curl perl make ca-certificates fontconfig \
        fonts-noto-cjk fonts-noto-cjk-extra \
        texlive latexmk texlive-latex-base texlive-latex-recommended \
        texlive-latex-extra texlive-luatex texlive-fonts-recommended \
        texlive-fonts-extra texlive-lang-cjk texlive-lang-chinese \
        texlive-lang-japanese texlive-plain-generic texlive-science && \
    # B. 手动执行触发器 (显式加速 + 逻辑精简)
    # 1. ldconfig (libc-bin 触发器，极快)
    ldconfig && \
    # 2. 建立文件索引 (eatmydata 加速 IO)
    eatmydata mktexlsr && \
    # 3. 建立字体映射 (eatmydata 加速 IO)
    eatmydata updmap-sys && \
    # 4. 编译格式 (核心优化点：只编译需要的引擎)
    # 这里的 trick 是：不运行 --all，而是手动指定常用的。
    # 如果你需要完全的兼容性，依然可以用 --all，但加上 eatmydata
    # eatmydata fmtutil-sys --byfmt xelatex && \
    # eatmydata fmtutil-sys --byfmt pdflatex && \
    eatmydata fmtutil-sys --byfmt lualatex && \
    # 注意：如果你确定需要日文纵书支持，取消下面这行的注释 (编译极慢)
    # eatmydata fmtutil-sys --byfmt uplatex && \
    # C. 清理
    apt-get clean && \
    rm -rf /usr/share/doc/* /usr/share/man/* /usr/share/info/* && \
    rm -rf /var/lib/apt/lists/* /var/log/* /tmp/*

# 5. Playwright 层
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    --mount=type=cache,target=/root/.cache/uv \
    uv pip install playwright && \
    apt-get update $APT_OPTS && \
    eatmydata playwright install-deps chromium && \
    playwright install chromium && \
    fc-cache -fv && \
    # --- 硬核清理开始 ---
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /var/log/* /tmp/* && \
    # 深度清理 Python 垃圾 (PyCache, Tests)
    find /usr/local/lib/python3.12 -name '__pycache__' -type d -exec rm -rf {} + && \
    find /usr/local/lib/python3.12 -name 'tests' -type d -exec rm -rf {} + && \
    # 剥离 Python 库中的调试符号 (Stripping symbols)
    find /usr/local/lib/python3.12/site-packages -name "*.so" -type f -exec strip --strip-unneeded {} + 2>/dev/null || true

WORKDIR /app

# 6. Python 依赖层
COPY requirements.txt .
RUN --mount=type=cache,target=/root/.cache/uv \
    uv pip install -r requirements.txt && \
    # 再次执行 Python 清理 (针对 requirements 里的包)
    find /usr/local/lib/python3.12 -name '__pycache__' -type d -exec rm -rf {} + && \
    find /usr/local/lib/python3.12 -name 'tests' -type d -exec rm -rf {} + && \
    find /usr/local/lib/python3.12/site-packages -name "*.so" -type f -exec strip --strip-unneeded {} + 2>/dev/null || true

# 7. 应用代码
COPY exporter/ /app/exporter/
COPY export-pdf.sh /usr/local/bin/export-pdf
RUN chmod +x /usr/local/bin/export-pdf

CMD ["/usr/local/bin/export-pdf"]