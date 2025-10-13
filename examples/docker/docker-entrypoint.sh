#!/usr/bin/env bash
set -euo pipefail

APP_PATH="${APP_PATH:-/workspace/app}"

if [ ! -d "$APP_PATH" ]; then
  echo "APP_PATH $APP_PATH does not exist. Set APP_PATH to your generated example app."
  exit 1
fi

cd "$APP_PATH"

bundle config set --local path "${BUNDLE_PATH:-/bundle}"
bundle config set --local without "${BUNDLE_WITHOUT:-""}"

if [ ! -f "Gemfile.lock" ]; then
  echo "Gemfile.lock not found under $APP_PATH. Run bundle install locally first or commit the lockfile."
fi

bundle check || bundle install

if [ -f "package.json" ]; then
  npm install
fi

bundle exec rails db:prepare

case "${1:-web}" in
  web)
    exec bundle exec rails server -b 0.0.0.0 -p "${PORT:-3000}"
    ;;
  worker)
    exec bundle exec rails solid_queue:start
    ;;
  scheduler)
    exec bundle exec bin/jobs --recurring_schedule_file="${SOLID_QUEUE_RECURRING_SCHEDULE_FILE:-config/recurring.yml}"
    ;;
  *)
    exec "$@"
    ;;
esac
