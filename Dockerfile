FROM python:3.12-slim
WORKDIR /app
RUN python -m pip install --upgrade pip --no-cache-dir
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt && \
    playwright install --with-deps chromium && \
    apt-get install -y --no-install-recommends \
    make \
    perl \
    fontconfig \
    latexmk \
    texlive-xetex \
    texlive-lang-chinese \
    texlive-latex-extra \
    texlive-plain-generic \
    fonts-noto-cjk \
    fonts-noto-cjk-extra && \
    rm -rf /var/lib/apt/lists/*
COPY exporter/ /app/exporter/
RUN fc-cache -fv
RUN latexmk --version && lualatex --version && python --version
