#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
temp_dir="$(mktemp -d)"
trap 'rm -rf "${temp_dir}"' EXIT

source "${script_dir}/bujo.sh"

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

assert_has_line() {
    local file="$1" line="$2"

    grep -Fqx -- "${line}" "${file}" || fail "expected '${line}' in ${file}"
}

assert_lacks_line() {
    local file="$1" line="$2"

    if grep -Fqx -- "${line}" "${file}"; then
        fail "did not expect '${line}' in ${file}"
    fi
}

assert_line_count() {
    local file="$1" line="$2" expected="$3" actual

    actual="$(grep -Fc -- "${line}" "${file}" || true)"
    if [[ "${actual}" != "${expected}" ]]; then
        fail "expected ${expected} occurrences of '${line}' in ${file}, got ${actual}"
    fi
}

assert_status() {
    local expected="$1" actual=0
    shift

    "$@" >/dev/null 2>&1 || actual="${?}"
    if [[ "${actual}" != "${expected}" ]]; then
        fail "expected exit status ${expected}, got ${actual} for ${*}"
    fi
}

enter_case() {
    local name="$1"

    mkdir -p "${temp_dir}/${name}"
    cd "${temp_dir}/${name}"
}

enter_case creation
bujo_new 2026 >/dev/null
bujo_new 2024 Feb >/dev/null
bujo_new 2026 Feb 28 >/dev/null

assert_has_line 2026 '---'
assert_has_line 2026 Dec
assert_has_line 2024-Feb '29 Thu'
assert_has_line 2026-Feb-28-Sat '8H'
assert_has_line 2026-Feb-28-Sat '20H'
assert_lacks_line 2026-Feb-28-Sat '21H'
assert_status 2 bujo_new
assert_status 2 bujo_migrate

touch unrecognized-file
assert_status 2 bujo_migrate unrecognized-file

enter_case month-migration
cat >2026-Feb <<'EOF'
2026 Feb
> next month task
> next month task
< new parent task
x existing completed task
~ existing deferred task
x absent parent task
---
EOF

cat >2026-Mar <<'EOF'
2026 Mar
---
EOF

cat >2026 <<'EOF'
2026
. existing completed task
. existing deferred task
---
after placeholder
EOF

bujo_migrate 2026-Feb >/dev/null
assert_line_count 2026-Mar '. next month task' 1
assert_has_line 2026 '. new parent task'
assert_has_line 2026 'x existing completed task'
assert_has_line 2026 '~ existing deferred task'
assert_lacks_line 2026 'x absent parent task'
assert_has_line 2026 'after placeholder'

enter_case day-migration
cat >2026-Feb-28-Sat <<'EOF'
2026 Feb 28 Sat
> next day task
< new month task
x existing completed task
~ absent month task
---
EOF

cat >2026-Mar-1-Sun <<'EOF'
2026 Mar 1 Sun
---
EOF

cat >2026-Feb <<'EOF'
2026 Feb
. existing completed task
---
EOF

bujo_migrate 2026-Feb-28-Sat >/dev/null
assert_has_line 2026-Mar-1-Sun '. next day task'
assert_has_line 2026-Feb '. new month task'
assert_has_line 2026-Feb 'x existing completed task'
assert_lacks_line 2026-Feb '~ absent month task'

printf 'All tests passed.\n'
