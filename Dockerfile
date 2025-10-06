FROM debian:testing-slim as build

RUN apt-get update && \
    apt-get install -y autoconf \
                       build-essential \
                       git \
                       libpcre2-dev \
                       libncurses-dev \
                       libcap2-dev && \
    rm -rf /var/lib/apt/lists/*

RUN git clone https://github.com/zsh-users/zsh.git /tmp/zsh
RUN cd /tmp/zsh && \
    ./Util/preconfig && \
    ./configure --prefix=/usr \
                --enable-cap \
                --enable-pcre \
                --enable-multibyte \
                --with-term-lib=ncursesw && \
    make && \
    make install.bin install.modules install.fns DESTDIR=/tmp/zsh-install

FROM debian:testing-slim
RUN apt-get update && \
    apt-get install -y libpcre2-8-0 libncursesw6 libcap2 libtinfo6 make && \
    rm -rf /var/lib/apt/lists/*

COPY --from=build /tmp/zsh-install /

RUN groupadd czhttpd && \
    useradd -m -g czhttpd -d /home/czhttpd -s /sbin/nologin czhttpd
USER czhttpd

ENV APP=/home/czhttpd/src
ENV PATH="$APP:$PATH"

RUN mkdir -p $APP/modules/ $APP/test/
COPY --chown=czhttpd:czhttpd modules/ $APP/modules/
COPY --chown=czhttpd:czhttpd test/ $APP/test/
COPY --chown=czhttpd:czhttpd czhttpd Makefile $APP/
RUN chmod +x $APP/czhttpd

WORKDIR $APP
RUN make clean

CMD ["czhttpd", "-v"]
