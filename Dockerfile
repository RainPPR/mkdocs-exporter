FROM python:3.12-slim
ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONDONTWRITEBYTECODE=1
ENV PLAYWRIGHT_BROWSERS_PATH=/ms-playwright
RUN pip install --no-cache-dir playwright
RUN apt-get update && \
    playwright install-deps chromium && \
    apt-get install -y --no-install-recommends \
        git curl perl make \
        ca-certificates \
        fontconfig \
        fonts-noto-cjk \
        fonts-noto-cjk-extra \
        latexmk \
        texlive-latex-base \
        texlive-latex-recommended \
        texlive-latex-extra \
        texlive-luatex \
        texlive-fonts-recommended \
        # texlive-fonts-extra \
        latex-cjk-all \
        texlive-lang-cjk \
        texlive-plain-generic \
        texlive-science && \
    rm -rf /var/lib/apt/lists/* && \
    fc-cache -fv
RUN playwright install chromium
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY exporter/ /app/exporter/
COPY export-pdf.sh /usr/local/bin/export-pdf
RUN chmod +x /usr/local/bin/export-pdf
CMD ["/usr/local/bin/export-pdf"]