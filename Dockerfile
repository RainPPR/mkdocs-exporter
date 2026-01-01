FROM python:3.12-slim
ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONDONTWRITEBYTECODE=1 \
    PLAYWRIGHT_BROWSERS_PATH=/ms-playwright \
    UV_SYSTEM_PYTHON=1
COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    echo 'path-exclude /usr/share/doc/*' > /etc/dpkg/dpkg.cfg.d/docker-clean && \
    echo 'path-exclude /usr/share/man/*' >> /etc/dpkg/dpkg.cfg.d/docker-clean && \
    echo 'path-exclude /usr/share/groff/*' >> /etc/dpkg/dpkg.cfg.d/docker-clean && \
    echo 'path-exclude /usr/share/info/*' >> /etc/dpkg/dpkg.cfg.d/docker-clean && \
    echo 'path-exclude /usr/share/lintian/*' >> /etc/dpkg/dpkg.cfg.d/docker-clean && \
    echo 'path-exclude /usr/share/linda/*' >> /etc/dpkg/dpkg.cfg.d/docker-clean && \
    uv pip install --no-cache-dir playwright && \
    apt-get update && playwright install-deps chromium && \
    apt-get install -y --no-install-recommends \
        git curl perl make \
        ca-certificates \
        fontconfig \
        fonts-noto-cjk \
        fonts-noto-cjk-extra \
        texlive latexmk \
        texlive-latex-base \
        texlive-latex-recommended \
        texlive-latex-extra \
        texlive-luatex \
        texlive-fonts-recommended \
        texlive-fonts-extra \
        texlive-lang-cjk \
        texlive-lang-chinese \
        texlive-lang-japanese \
        texlive-plain-generic \
        texlive-science && \
    fc-cache -fv && \
    playwright install chromium && \
    rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY requirements.txt .
RUN --mount=type=cache,target=/root/.cache/uv \
    uv pip install --no-cache-dir -r requirements.txt
COPY exporter/ /app/exporter/
COPY export-pdf.sh /usr/local/bin/export-pdf
RUN chmod +x /usr/local/bin/export-pdf
CMD ["/usr/local/bin/export-pdf"]