# 使用 R + Shiny Server 的穩定版本
FROM rocker/shiny:4.3.1

# 更新系統套件
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

# 安裝 R 套件
RUN R -e "install.packages(c('shiny', 'dplyr', 'readr', 'leaflet', 'stringr', 'rvest', 'httr', 'bslib'))"

# 把 app 檔案加進 container 裡
COPY . /srv/shiny-server/

# 設定權限
RUN chown -R shiny:shiny /srv/shiny-server

# 開放 port 3838
EXPOSE 3838

# 啟動 shiny server
CMD ["/usr/bin/shiny-server"]
