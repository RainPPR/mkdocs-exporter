# syntax=docker/dockerfile:1
FROM python:3.12-slim

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONDONTWRITEBYTECODE=1 \
    PLAYWRIGHT_BROWSERS_PATH=/ms-playwright \
    UV_SYSTEM_PYTHON=1 \
    UV_CONCURRENT_DOWNLOADS=8 \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8

COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv

RUN apt-get update && \
    apt-get install -y --no-install-recommends eatmydata && \
    echo 'path-exclude /usr/share/doc/*' > /etc/dpkg/dpkg.cfg.d/docker-clean && \
    echo 'path-exclude /usr/share/man/*' >> /etc/dpkg/dpkg.cfg.d/docker-clean && \
    echo 'path-exclude /usr/share/groff/*' >> /etc/dpkg/dpkg.cfg.d/docker-clean && \
    echo 'path-exclude /usr/share/info/*' >> /etc/dpkg/dpkg.cfg.d/docker-clean && \
    echo 'path-exclude /usr/share/lintian/*' >> /etc/dpkg/dpkg.cfg.d/docker-clean && \
    echo 'path-exclude /usr/share/linda/*' >> /etc/dpkg/dpkg.cfg.d/docker-clean && \
    echo 'path-exclude /usr/share/locale/*' >> /etc/dpkg/dpkg.cfg.d/docker-clean && \
    rm -rf /var/lib/apt/lists/*

RUN uv pip install playwright && \
    apt-get update && \
    eatmydata playwright install-deps chromium && \
    playwright install chromium && \
    fc-cache -fv && rm -rf /var/lib/apt/lists/*

RUN apt-get update && \
    eatmydata apt-get install -y --no-install-recommends -o Dpkg::Options::="--no-triggers" \
        git make fontconfig texlive latexmk texlive-luatex \
        texlive-latex-base texlive-latex-extra texlive-latex-recommended \
        texlive-pictures texlive-plain-generic texlive-fonts-recommended \
        texlive-lang-cjk texlive-lang-chinese texlive-lang-japanese && \
    ldconfig && \
    eatmydata mktexlsr && \
    eatmydata updmap-sys && \
    eatmydata fmtutil-sys --byfmt lualatex && \
    truncate -s 0 /var/lib/dpkg/info/tex-common.postinst && \
    truncate -s 0 /var/lib/dpkg/info/tex-common.triggers && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY requirements.txt .
RUN uv pip install -r requirements.txt

COPY exporter/ /app/exporter/
COPY mkdocs-export.sh /usr/local/bin/mkdocs-export
RUN chmod +x /usr/local/bin/mkdocs-export

CMD ["/usr/local/bin/mkdocs-export"]