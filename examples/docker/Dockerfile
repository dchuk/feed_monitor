FROM ruby:3.3

ENV LANG=C.UTF-8 \
    BUNDLE_PATH=/bundle \
    APP_PATH=/workspace/app

RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends build-essential nodejs npm postgresql-client && \
    npm install --global npm@latest && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /workspace

COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint
RUN chmod +x /usr/local/bin/docker-entrypoint

ENTRYPOINT ["docker-entrypoint"]
CMD ["web"]
