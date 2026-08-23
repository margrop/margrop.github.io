FROM debian:trixie-slim

RUN apt-get update \
    && apt-get install -y --no-install-recommends pgbouncer postgresql-client ca-certificates \
    && rm -rf /var/lib/apt/lists/*

USER postgres
ENTRYPOINT ["pgbouncer"]
CMD ["/etc/pgbouncer/pgbouncer.ini"]
