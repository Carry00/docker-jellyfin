# syntax=docker/dockerfile:1

FROM ghcr.io/linuxserver/baseimage-ubuntu:noble

# set version label
ARG BUILD_DATE
ARG VERSION
ARG JELLYFIN_RELEASE
LABEL build_version="Linuxserver.io version:- ${VERSION} Build-date:- ${BUILD_DATE}"
LABEL maintainer="thelamer"

# environment settings
ARG DEBIAN_FRONTEND="noninteractive"
ENV NVIDIA_DRIVER_CAPABILITIES="compute,video,utility"
# https://github.com/dlemstra/Magick.NET/issues/707#issuecomment-785351620
ENV MALLOC_TRIM_THRESHOLD_=131072

# WebDAV environment variables
ENV WEBDAV_URL=""
ENV WEBDAV_USERNAME=""
ENV WEBDAV_PASSWORD=""
ENV WEBDAV_MOUNT_PATH="/mnt/webdav"

RUN \
  echo "**** install jellyfin *****" && \
  curl -s https://repo.jellyfin.org/ubuntu/jellyfin_team.gpg.key | gpg --dearmor | tee /usr/share/keyrings/jellyfin.gpg >/dev/null && \
  echo 'deb [arch=amd64 signed-by=/usr/share/keyrings/jellyfin.gpg] https://repo.jellyfin.org/ubuntu noble main' > /etc/apt/sources.list.d/jellyfin.list && \
  if [ -z ${JELLYFIN_RELEASE+x} ]; then \
    JELLYFIN_RELEASE=$(curl -sX GET https://repo.jellyfin.org/ubuntu/dists/noble/main/binary-amd64/Packages |grep -A 7 -m 1 'Package: jellyfin-server' | awk -F ': ' '/Version/{print $2;exit}'); \
  fi && \
  apt-get update && \
  apt-get install -y --no-install-recommends \
    at \
    jellyfin=${JELLYFIN_RELEASE} \
    mesa-va-drivers \
    xmlstarlet \
    ca-certificates \
    fuse3 \
    curl \
    unzip && \
  echo "**** install rclone ****" && \
  RCLONE_ARCH=$(dpkg --print-architecture) && \
  if [ "$RCLONE_ARCH" = "amd64" ]; then RCLONE_ARCH="amd64"; fi && \
  if [ "$RCLONE_ARCH" = "arm64" ]; then RCLONE_ARCH="arm64"; fi && \
  curl -L "https://downloads.rclone.org/rclone-current-linux-${RCLONE_ARCH}.zip" -o rclone.zip && \
  unzip rclone.zip && \
  cp rclone-*/rclone /usr/local/bin/ && \
  chmod +x /usr/local/bin/rclone && \
  rm -rf rclone* && \
  echo "**** cleanup ****" && \
  rm -rf \
    /tmp/* \
    /var/lib/apt/lists/* \
    /var/tmp/*

# add local files
COPY root/ /

# Set permissions for scripts
RUN if [ -f /etc/cont-init.d/50-webdav ]; then chmod +x /etc/cont-init.d/50-webdav; fi && \
    if [ -d /etc/services.d/webdav ]; then \
      chmod +x /etc/services.d/webdav/run; \
      chmod +x /etc/services.d/webdav/finish; \
    fi

# ports and volumes
EXPOSE 8096 8920
VOLUME /config
