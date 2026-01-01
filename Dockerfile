FROM python:3.12
WORKDIR /app
RUN python -m pip install --upgrade pip --no-cache-dir
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt && \
    playwright install --with-deps \
    apt-get install -y fontconfig texlive-full fonts-noto-cjk fonts-noto-cjk-extra && \
    rm -rf /var/lib/apt/lists/*
COPY exporter/ /app/exporter/
COPY export-pdf.sh /usr/local/bin/export-pdf
RUN chmod +x /usr/local/bin/export-pdf
RUN fc-cache -fv
