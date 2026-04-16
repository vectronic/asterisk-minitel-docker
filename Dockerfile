FROM docker.io/library/ubuntu:26.04 AS builder

ENV DEBIAN_FRONTEND=noninteractive

USER root

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        git \
        python3 \
        python3-venv; \
    rm -rf /var/lib/apt/lists/*

# Install Asterisk with PJSIP and Softmodem support.
RUN set -eux; \
    apt-get update; \
    cd /tmp; \
    curl -fsSL https://downloads.asterisk.org/pub/telephony/asterisk/asterisk-22-current.tar.gz -o asterisk-22-current.tar.gz; \
    source_dir="$(tar -tzf asterisk-22-current.tar.gz | head -1 | cut -d/ -f1)"; \
    tar -xzf asterisk-22-current.tar.gz -C /usr/src; \
    rm asterisk-22-current.tar.gz; \
    curl -fsSL https://raw.githubusercontent.com/johnnewcombe/asterisk-Softmodem/app_softmodem/app_softmodem.c -o "/usr/src/${source_dir}/apps/app_softmodem.c"; \
    cd "/usr/src/${source_dir}"; \
    ./contrib/scripts/install_prereq install; \
    ./configure --with-pjproject-bundled; \
    cd menuselect; \
    make menuselect; \
    cd ..; \
    make menuselect-tree; \
    menuselect/menuselect --disable-category MENUSELECT_ADDONS menuselect.makeopts; \
    menuselect/menuselect --disable-category MENUSELECT_APPS menuselect.makeopts; \
    menuselect/menuselect --disable-category MENUSELECT_FUNCS menuselect.makeopts; \
    menuselect/menuselect --disable-category MENUSELECT_RES menuselect.makeopts; \
    menuselect/menuselect --disable-category MENUSELECT_TESTS menuselect.makeopts; \
    menuselect/menuselect --disable-category MENUSELECT_UTILS menuselect.makeopts; \
    menuselect/menuselect --enable codec_ulaw menuselect.makeopts; \
    menuselect/menuselect --enable res_rtp_asterisk menuselect.makeopts; \
    menuselect/menuselect --enable res_timing_timerfd menuselect.makeopts; \
    menuselect/menuselect --enable chan_pjsip menuselect.makeopts; \
    menuselect/menuselect --enable res_pjsip_registrar menuselect.makeopts; \
    menuselect/menuselect --enable res_pjsip_messaging menuselect.makeopts; \
    menuselect/menuselect --enable res_pjsip_sdp_rtp menuselect.makeopts; \
    menuselect/menuselect --enable res_pjsip_session menuselect.makeopts; \
    menuselect/menuselect --enable res_pjsip_logger menuselect.makeopts; \
    menuselect/menuselect --enable res_pjsip_authenticator_digest menuselect.makeopts; \
    menuselect/menuselect --enable res_pjsip_endpoint_identifier_ip menuselect.makeopts; \
    menuselect/menuselect --enable res_pjsip_endpoint_identifier_user menuselect.makeopts; \
    menuselect/menuselect --enable pbx_config menuselect.makeopts; \
    menuselect/menuselect --enable app_dial menuselect.makeopts; \
    menuselect/menuselect --enable app_softmodem menuselect.makeopts; \
    menuselect/menuselect --check-deps menuselect.makeopts; \
    make -j"$(nproc)" all install; \
    rm -rf "/usr/src/${source_dir}"

# Install Minitel Server.
RUN set -eux; \
    git clone --depth 1 https://github.com/BwanaFr/minitel-server.git /minitel-server; \
    cd /minitel-server; \
    sed -i 's/PROCESS_PARITY[[:space:]]*=[[:space:]]*True/PROCESS_PARITY = False/' minitel_server/constant.py; \
    python3 -m venv .venv; \
    . .venv/bin/activate; \
    pip install --no-cache-dir pyyaml

# Record only the runtime packages required by the compiled binaries and Python venv.
RUN set -eux; \
    { \
        echo /usr/sbin/asterisk; \
        find /usr/lib/asterisk -type f -name '*.so'; \
        echo /minitel-server/.venv/bin/python3; \
    } | while read -r binary; do \
        ldd "$binary" | awk '/=> \/+/ { print $3 } /^\// { print $1 }'; \
    done | sort -u > /tmp/runtime-libs.txt; \
    while read -r lib; do \
        [ -e "$lib" ] || continue; \
        echo "$lib"; \
        real="$(readlink -f "$lib" || true)"; \
        [ -n "$real" ] && echo "$real" || true; \
    done < /tmp/runtime-libs.txt | sort -u > /tmp/runtime-lib-files.txt; \
    : > /tmp/runtime-custom-libs.txt; \
    while read -r lib; do \
        if dpkg-query -S "$lib" >/dev/null 2>&1; then \
            :; \
        else \
            echo "$lib" >> /tmp/runtime-custom-libs.txt; \
        fi; \
    done < /tmp/runtime-lib-files.txt; \
    tar -czf /tmp/runtime-custom-libs.tar -T /tmp/runtime-custom-libs.txt; \
    { \
        echo bash; \
        echo ca-certificates; \
        echo python3; \
        xargs -r dpkg-query -S < /tmp/runtime-lib-files.txt | cut -d: -f1; \
    } | sort -u > /tmp/runtime-packages.txt

FROM docker.io/library/ubuntu:26.04

ENV DEBIAN_FRONTEND=noninteractive

USER root
WORKDIR /

COPY --from=builder /tmp/runtime-packages.txt /tmp/runtime-packages.txt
COPY --from=builder /tmp/runtime-custom-libs.tar /tmp/runtime-custom-libs.tar

RUN set -eux; \
    apt-get update; \
    xargs -r apt-get install -y --no-install-recommends < /tmp/runtime-packages.txt; \
    tar -xzf /tmp/runtime-custom-libs.tar -C /; \
    ldconfig; \
    rm -rf /var/lib/apt/lists/* /tmp/runtime-packages.txt /tmp/runtime-custom-libs.tar

COPY --from=builder /etc/asterisk /etc/asterisk
COPY --from=builder /usr/lib/asterisk /usr/lib/asterisk
COPY --from=builder /usr/sbin/asterisk /usr/sbin/asterisk
COPY --from=builder /var/lib/asterisk /var/lib/asterisk
COPY --from=builder /var/log/asterisk /var/log/asterisk
COPY --from=builder /var/spool/asterisk /var/spool/asterisk
COPY --from=builder /minitel-server /minitel-server

COPY /scripts/start.sh /start.sh

RUN chmod +x /start.sh

CMD ["/start.sh"]
