# 使用 R 官方的 Shiny base image
FROM rocker/shiny:4.3.1

# 安裝系統套件：這些是 shiny app 常見依賴
RUN apt-get update && apt-get install -y \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
    libfontconfig1-dev \
    libfreetype6-dev \
    libtiff5-dev \
    libjpeg-dev \
    libpng-dev \
    libglpk-dev \
    libgdal-dev \
    libudunits2-dev \
    libprotobuf-dev \
    protobuf-compiler \
    libharfbuzz-dev \
    libfribidi-dev \
    libsqlite3-dev \
    libmariadbd-dev \
    libpq-dev \
    libssh2-1-dev \
    libgit2-dev \
    && rm -rf /var/lib/apt/lists/*

# 安裝你需要的 R 套件
RUN R -e "install.packages(c('shiny', 'leaflet', 'dplyr', 'readr', 'stringr', 'rvest', 'bslib', 'tidytext'), repos = 'https://cloud.r-project.org')"

# 將整個專案複製到 shiny server 資料夾
COPY . /srv/shiny-server/

# 設定權限給 shiny 使用者
RUN chown -R shiny:shiny /srv/shiny-server

# 開放 port
EXPOSE 3838

# 啟動 shiny server
CMD ["/usr/bin/shiny-server"]
