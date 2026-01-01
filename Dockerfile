# syntax=docker/dockerfile:1
FROM python:3.12-slim

# 1. 环境配置
ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONDONTWRITEBYTECODE=1 \
    PLAYWRIGHT_BROWSERS_PATH=/ms-playwright \
    UV_SYSTEM_PYTHON=1 \
    # 强制 uv 并发下载，压榨带宽
    UV_CONCURRENT_DOWNLOADS=16 \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    # 增加重试，因为没有缓存兜底，网络必须稳
    APT_OPTS="-o Acquire::Retries=5 -o Acquire::http::Timeout=20"

# 2. 引入 uv
COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv

# 3. 基础层：Eatmydata + DPKG 排除
# 去掉了所有 mount，直接 run
RUN apt-get update $APT_OPTS && \
    apt-get install -y --no-install-recommends eatmydata && \
    # --- DPKG 排除配置 (保持不变，这是减小体积的关键) ---
    echo 'path-exclude /usr/share/doc/*' > /etc/dpkg/dpkg.cfg.d/docker-clean && \
    echo 'path-exclude /usr/share/man/*' >> /etc/dpkg/dpkg.cfg.d/docker-clean && \
    echo 'path-exclude /usr/share/groff/*' >> /etc/dpkg/dpkg.cfg.d/docker-clean && \
    echo 'path-exclude /usr/share/info/*' >> /etc/dpkg/dpkg.cfg.d/docker-clean && \
    echo 'path-exclude /usr/share/lintian/*' >> /etc/dpkg/dpkg.cfg.d/docker-clean && \
    echo 'path-exclude /usr/share/linda/*' >> /etc/dpkg/dpkg.cfg.d/docker-clean && \
    echo 'path-exclude /usr/share/locale/*' >> /etc/dpkg/dpkg.cfg.d/docker-clean && \
    # 清理
    rm -rf /var/lib/apt/lists/*

# 4. TeXLive 层 (无缓存，纯下载)
RUN apt-get update $APT_OPTS && \
    # 禁止 Trigger
    eatmydata apt-get install -y --no-install-recommends -o Dpkg::Options::="--no-triggers" $APT_OPTS \
        git curl perl make ca-certificates fontconfig \
        texlive latexmk texlive-latex-base texlive-latex-recommended \
        texlive-latex-extra texlive-luatex texlive-fonts-recommended \
        fonts-noto-cjk texlive-lang-cjk texlive-lang-chinese \
        texlive-lang-japanese texlive-plain-generic texlive-science && \
    # 手动 Trigger
    ldconfig && \
    eatmydata mktexlsr && \
    eatmydata updmap-sys && \
    # --- 格式编译选择 ---
    # 如果你确定只用 lualatex，就保留这一行。
    # 但如果为了速度，xelatex 通常更快。这里按你的原代码保留 lualatex。
    eatmydata fmtutil-sys --byfmt lualatex && \
    # --- 阉割 Trigger (保持不变) ---
    truncate -s 0 /var/lib/dpkg/info/tex-common.postinst && \
    truncate -s 0 /var/lib/dpkg/info/tex-common.triggers && \
    # --- 清理 ---
    # 这里不需要 apt-get clean，因为没有 mount，且下一行删除了 lists
    # 但为了以防万一删掉 archives
    rm -rf /var/cache/apt/archives/* && \
    rm -rf /usr/share/doc/* /usr/share/man/* /usr/share/info/* && \
    rm -rf /var/lib/apt/lists/* /var/log/* /tmp/*

# 5. Playwright 层
RUN uv pip install playwright && \
    apt-get update $APT_OPTS && \
    # 依然使用 eatmydata 加速系统依赖安装
    eatmydata playwright install-deps chromium && \
    playwright install chromium && \
    fc-cache -fv && \
    # --- 清理 ---
    rm -rf /var/lib/apt/lists/* /var/log/* /tmp/* && \
    rm -rf /var/cache/apt/archives/* && \
    # Python 瘦身
    find /usr/local/lib/python3.12 -name '__pycache__' -type d -exec rm -rf {} + && \
    find /usr/local/lib/python3.12 -name 'tests' -type d -exec rm -rf {} + && \
    find /usr/local/lib/python3.12/site-packages -name "*.so" -type f -exec strip --strip-unneeded {} + 2>/dev/null || true

WORKDIR /app

# 6. Python 依赖层
COPY requirements.txt .
# 直接安装，不挂载缓存
RUN uv pip install -r requirements.txt && \
    # 再次清理
    find /usr/local/lib/python3.12 -name '__pycache__' -type d -exec rm -rf {} + && \
    find /usr/local/lib/python3.12 -name 'tests' -type d -exec rm -rf {} + && \
    find /usr/local/lib/python3.12/site-packages -name "*.so" -type f -exec strip --strip-unneeded {} + 2>/dev/null || true

# 7. 应用代码
COPY exporter/ /app/exporter/
COPY export-pdf.sh /usr/local/bin/export-pdf
RUN chmod +x /usr/local/bin/export-pdf

CMD ["/usr/local/bin/export-pdf"]