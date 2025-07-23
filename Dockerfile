# 使用 R + Shiny Server 的穩定版本
FROM rocker/shiny:4.3.1

# 設定環境變數
ENV RENV_VERSION 1.0.3

# 更新系統套件並安裝依賴
RUN apt-get update && apt-get install -y \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
    libgit2-dev \
    libglpk-dev \
    libharfbuzz-dev \
    libfribidi-dev \
    libfreetype6-dev \
    libpng-dev \
    libtiff5-dev \
    libjpeg-dev \
    && rm -rf /var/lib/apt/lists/*

# 安裝 R 套件 (確保版本相容性)
RUN R -e "install.packages(c('shiny', 'httr', 'tidytext', 'dplyr', 'readr', 'leaflet', 'stringr', 'rvest', 'bslib'), repos='https://cloud.r-project.org/')"

# 創建 app 目錄
RUN mkdir -p /srv/shiny-server/myapp

# 複製 shiny-server 配置文件
COPY shiny-server.conf /etc/shiny-server/shiny-server.conf

# 複製應用程式檔案到指定目錄
COPY app.R /srv/shiny-server/myapp/
COPY gtfs/ /srv/shiny-server/myapp/gtfs/

# 設定目錄權限
RUN chown -R shiny:shiny /srv/shiny-server

# 暴露 port 3838 (Render 會自動映射到環境變數 PORT)
EXPOSE 3838

# 創建啟動腳本
RUN echo '#!/bin/bash\n\
# 如果 Render 提供了 PORT 環境變數，使用它；否則使用預設的 3838\n\
if [ -n "$PORT" ]; then\n\
    sed -i "s/listen 3838/listen $PORT/" /etc/shiny-server/shiny-server.conf\n\
fi\n\
exec /usr/bin/shiny-server\n' > /usr/local/bin/start-shiny.sh \
    && chmod +x /usr/local/bin/start-shiny.sh

# 啟動 shiny server
CMD ["/usr/local/bin/start-shiny.sh"]
