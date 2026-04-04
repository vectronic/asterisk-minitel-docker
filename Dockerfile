FROM docker.io/library/ubuntu:26.04

ENV DEBIAN_FRONTEND=noninteractive

USER root

RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y curl git python3-venv

# Install Asterisk with PJSIP and Softmodem support    

RUN cd / && \
    curl https://downloads.asterisk.org/pub/telephony/asterisk/asterisk-22-current.tar.gz > asterisk-22-current.tar.gz && \
    tar -zxvf asterisk-22-current.tar.gz && \
    rm asterisk-22-current.tar.gz && \
    curl https://raw.githubusercontent.com/johnnewcombe/asterisk-Softmodem/app_softmodem/app_softmodem.c > asterisk-22.8.2/apps/app_softmodem.c && \
    cd asterisk-22.8.2 && \
    ./contrib/scripts/install_prereq install && \
    ./configure && \
    cd menuselect && \
    make menuselect && \
    cd .. && \
    make menuselect-tree && \
    menuselect/menuselect --disable-category MENUSELECT_ADDONS menuselect.makeopts && \
    menuselect/menuselect --disable-category MENUSELECT_APPS menuselect.makeopts && \
    menuselect/menuselect --disable-category MENUSELECT_FUNCS menuselect.makeopts && \
    menuselect/menuselect --disable-category MENUSELECT_RES menuselect.makeopts && \
    menuselect/menuselect --disable-category MENUSELECT_TESTS menuselect.makeopts && \
    menuselect/menuselect --disable-category MENUSELECT_UTILS menuselect.makeopts && \
    menuselect/menuselect --enable chan_pjsip menuselect.makeopts && \
    menuselect/menuselect --enable app_softmodem menuselect.makeopts && \
    menuselect/menuselect --check-deps menuselect.makeopts && \
    make -j 16 all install && \
    cd / && \
    rm -rf /asterisk-22.8.2

# Install Minitel Server

RUN cd / && \
    git clone --depth 1 https://github.com/BwanaFr/minitel-server.git && \
    cd minitel-server && \
    python3 -m venv .venv && \
    . .venv/bin/activate && \
    pip install pyyaml

COPY /scripts/start.sh start.sh

CMD ["./start.sh"]
