FROM postgres:15

RUN apt-get update && apt-get install -y \
    build-essential \
    postgresql-server-dev-15 \
    && rm -rf /var/lib/apt/lists/*

COPY . /pg_abac

RUN cd /pg_abac && \
    make PG_CONFIG=/usr/lib/postgresql/15/bin/pg_config && \
    make install PG_CONFIG=/usr/lib/postgresql/15/bin/pg_config

COPY docker-init.sh /docker-entrypoint-initdb.d/01-init.sh
RUN chmod +x /docker-entrypoint-initdb.d/01-init.sh
