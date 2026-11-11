#!/usr/bin/env bash
# Runs `flutter build apk "$@"`, retrying up to 3 times on transient Gradle/network failures only.
set -o pipefail

log_file="${RUNNER_TEMP:-/tmp}/flutter-build-apk.log"

for attempt in 1 2 3; do
  echo "Android build attempt ${attempt}/3"

  if flutter build apk "$@" 2>&1 | tee "${log_file}"; then
    exit 0
  else
    build_status=$?
  fi

  if grep -Eiq 'HTTP response code: 5[0-9]{2}|timed out|temporary failure in name resolution|connection reset|connection refused|remote host terminated the handshake|Hash of downloaded file .* does not match expected' "${log_file}"; then
    if [[ "${attempt}" -lt 3 ]]; then
      delay=$((attempt * 20))
      echo "Transient Gradle/network failure detected. Retrying in ${delay}s..."
      sleep "${delay}"
      continue
    fi

    echo "Gradle/network download failed after 3 attempts."
  else
    echo "Build failed for a non-transient reason; not retrying."
  fi

  exit "${build_status}"
done
