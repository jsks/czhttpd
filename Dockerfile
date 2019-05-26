FROM zshusers/zsh:master

RUN rm -rf /usr/share/zsh/*/scripts/newuser
RUN install_packages make

RUN groupadd czhttpd \
        && useradd -m -g czhttpd -d /home/czhttpd -s /sbin/nologin czhttpd
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
