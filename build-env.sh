#!/bin/bash

# Copyright 2021 InfAI (CC SES)
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# The whole runtime configuration of the UI hangs on this one download, so the
# container must not start nginx without it: a started container that serves no
# env.json reports ready while every UI instance behind it is blank.
set -euo pipefail

TEMPLATE_RETRIES="${TEMPLATE_RETRIES:-5}"
TEMPLATE_RETRY_DELAY="${TEMPLATE_RETRY_DELAY:-3}"
TEMPLATE_TIMEOUT="${TEMPLATE_TIMEOUT:-20}"

TEMPLATE=/tmp/env.template.json
TARGET=/usr/share/nginx/html/env.json

if [ -z "${TEMPLATE_URL:-}" ]; then
  echo "TEMPLATE_URL is not set, cannot build env.json" >&2
  exit 1
fi

echo "Downloading template from $TEMPLATE_URL"
attempt=1
while true; do
  # Both halves have to hold: curl writes no file at all when it cannot connect,
  # and returns the 404 page as the body when the URL is wrong.
  if curl -fsS --max-time "$TEMPLATE_TIMEOUT" -o "$TEMPLATE" "$TEMPLATE_URL" \
     && jq -e . "$TEMPLATE" > /dev/null 2>&1; then
    break
  fi
  if [ "$attempt" -ge "$TEMPLATE_RETRIES" ]; then
    echo "Template download failed $attempt times, giving up without starting nginx" >&2
    exit 1
  fi
  echo "Template download attempt $attempt failed, retrying in ${TEMPLATE_RETRY_DELAY}s" >&2
  attempt=$((attempt + 1))
  sleep "$TEMPLATE_RETRY_DELAY"
done
echo "Downloaded template on attempt $attempt"

echo "Filling template with ENV"
envsubst < "$TEMPLATE" > "$TARGET.part"

# A variable holding a quote or a newline produces a file nginx serves happily
# and the UI cannot parse, which looks exactly like the outage this guards.
if ! jq -e . "$TARGET.part" > /dev/null 2>&1; then
  echo "Filled template is not valid JSON, check the environment variables" >&2
  rm -f "$TARGET.part"
  exit 1
fi

mv "$TARGET.part" "$TARGET"
chmod a+r "$TARGET"
echo "Starting nginx..."
