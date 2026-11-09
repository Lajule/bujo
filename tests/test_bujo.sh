#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
test_dir="$(mktemp -d)"
trap 'rm -rf "${test_dir}"' EXIT
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

assert_count() {
    local file="$1" line="$2" expected="$3" actual
    actual="$(grep -Fc -- "${line}" "${file}" || true)"
    [[ "${actual}" == "${expected}" ]] || fail "expected ${expected} occurrences of '${line}' in ${file}, got ${actual}"
}

mkdir "${test_dir}/creation"
cd "${test_dir}/creation"
bujo_new 2026 >/dev/null
bujo_new 2024 Feb >/dev/null
bujo_new 2026 Feb 28 >/dev/null
assert_has_line 2026 '@MIGRATED@'
assert_has_line 2026 Dec
assert_has_line 2024-Feb '29 Thu'
assert_has_line 2026-Feb-28-Sat '8H'
assert_has_line 2026-Feb-28-Sat '20H'
assert_lacks_line 2026-Feb-28-Sat '21H'

if bujo_new >/dev/null 2>&1; then
    fail 'bujo_new without arguments should fail'
else
    [[ "$?" == 2 ]] || fail 'bujo_new without arguments should return status 2'
fi
if bujo_migrate >/dev/null 2>&1; then
    fail 'bujo_migrate without arguments should fail'
else
    [[ "$?" == 2 ]] || fail 'bujo_migrate without arguments should return status 2'
fi
touch unrecognized-file
if bujo_migrate unrecognized-file >/dev/null 2>&1; then
    fail 'bujo_migrate should reject unrecognized filenames'
else
    [[ "$?" == 2 ]] || fail 'unrecognized migration filename should return status 2'
fi

mkdir "${test_dir}/month-migration"
cd "${test_dir}/month-migration"
cat >2026-Feb <<'EOF'
2026 Feb
> next month task
> next month task
< new parent task
x existing completed task
~ existing deferred task
x absent parent task
@MIGRATED@
EOF
cat >2026-Mar <<'EOF'
2026 Mar
@MIGRATED@
EOF
cat >2026 <<'EOF'
2026
. existing completed task
. existing deferred task
@MIGRATED@
after placeholder
EOF
bujo_migrate 2026-Feb >/dev/null
assert_count 2026-Mar '. next month task' 1
assert_has_line 2026 '. new parent task'
assert_has_line 2026 'x existing completed task'
assert_has_line 2026 '~ existing deferred task'
assert_lacks_line 2026 'x absent parent task'
assert_has_line 2026 'after placeholder'

mkdir "${test_dir}/day-migration"
cd "${test_dir}/day-migration"
cat >2026-Feb-28-Sat <<'EOF'
2026 Feb 28 Sat
> next day task
< new month task
x existing completed task
~ absent month task
@MIGRATED@
EOF
cat >2026-Mar-1-Sun <<'EOF'
2026 Mar 1 Sun
@MIGRATED@
EOF
cat >2026-Feb <<'EOF'
2026 Feb
. existing completed task
@MIGRATED@
EOF
bujo_migrate 2026-Feb-28-Sat >/dev/null
assert_has_line 2026-Mar-1-Sun '. next day task'
assert_has_line 2026-Feb '. new month task'
assert_has_line 2026-Feb 'x existing completed task'
assert_lacks_line 2026-Feb '~ absent month task'

printf 'All tests passed.\n'
