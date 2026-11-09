# Create a year, month, or day journal file based on the number of arguments.
bujo_new() {
    case $# in
        1) _bujo_new_year "$@" ;;
        2) _bujo_new_month "$@" ;;
        3) _bujo_new_day "$@" ;;
        *) echo 'usage: bujo_new <year> [month [day]]' >&2; return 2 ;;
    esac
}

_bujo_new_year() {
    local year="${1:-}"
    [[ -n "${year}" ]] || { echo 'usage: bujo_new <year>' >&2; return 2; }
    LC_ALL=C date -d "Jan 1 ${year}" '+%Y' >/dev/null || return 1
    printf '%d\n. existing task\n@MIGRATED@\nJan\nFeb\nMar\nApr\nMay\nJun\nJul\nAug\nSep\nOct\nNov\nDec\n' "${year}" >"${year}"
    printf 'created %s\n' "${year}"
}

_bujo_new_month() {
    local year="${1:-}" month="${2:-}" short last_day filename day weekday
    [[ -n "${year}" && -n "${month}" ]] || { echo 'usage: bujo_new <year> <month>' >&2; return 2; }
    short="$(LC_ALL=C date -d "${month} 1 ${year}" '+%b')" || return 1
    last_day="$(LC_ALL=C date -d "${month} 1 ${year} +1 month -1 day" '+%d')" || return 1
    last_day=$((10#${last_day})); filename="${year}-${short}"
    {
        printf '%d %s\n. existing task\n@MIGRATED@\n' "${year}" "${short}"
        for ((day = 1; day <= last_day; day++)); do
            weekday="$(LC_ALL=C date -d "${month} ${day} ${year}" '+%a')" || return 1
            printf '%d %s\n' "${day}" "${weekday}"
        done
    } >"${filename}"
    printf 'created %s\n' "${filename}"
}

_bujo_new_day() {
    local year="${1:-}" month="${2:-}" day="${3:-}" short weekday filename
    [[ -n "${year}" && -n "${month}" && -n "${day}" ]] || { echo 'usage: bujo_new <year> <month> <day>' >&2; return 2; }
    short="$(LC_ALL=C date -d "${month} ${day} ${year}" '+%b')" || return 1
    weekday="$(LC_ALL=C date -d "${month} ${day} ${year}" '+%a')" || return 1
    filename="${year}-${short}-${day}-${weekday}"
    printf '%d %s %d %s\n. existing task\n@MIGRATED@\n8H\n9H\n10H\n11H\n12H\n13H\n14H\n15H\n16H\n17H\n18H\n19H\n20H' "${year}" "${short}" "${day}" "${weekday}" >"${filename}"
    printf 'created %s\n' "${filename}"
}

# Move marked tasks from a journal file to its next period and parent period.
bujo_migrate() {
    local source="${1:-}" target parent year month day weekday iso_date actual_weekday
    [[ -n "${source}" ]] || { echo 'usage: bujo_migrate <file>' >&2; return 2; }
    [[ -f "${source}" ]] || { printf 'bujo_migrate: source file not found: %s\n' "${source}" >&2; return 1; }
    case "${source}" in
        ([0-9][0-9][0-9][0-9])
            target=$((10#${source} + 1))
            [[ ! -f "${target}" ]] || _bujo_migrate_to "${source}" "${target}" '>' || return 1
            ;;
        ([0-9][0-9][0-9][0-9]-[A-Z][a-z][a-z])
            year="${source%%-*}"; month="${source#*-}"
            target="$(LC_ALL=C date -d "${month} 1 ${year} +1 month" '+%Y-%b')" || return 1
            [[ ! -f "${target}" ]] || _bujo_migrate_to "${source}" "${target}" '>' || return 1
            [[ ! -f "${year}" ]] || _bujo_migrate_to "${source}" "${year}" '<' || return 1
            ;;
        ([0-9][0-9][0-9][0-9]-[A-Z][a-z][a-z]-[0-9]-[A-Z][a-z][a-z]|[0-9][0-9][0-9][0-9]-[A-Z][a-z][a-z]-[0-9][0-9]-[A-Z][a-z][a-z])
            IFS=- read -r year month day weekday <<< "${source}"
            iso_date="$(LC_ALL=C date -d "${month} ${day} ${year}" '+%F' 2>/dev/null)" || return 2
            actual_weekday="$(LC_ALL=C date -d "${iso_date}" '+%a')" || return 1
            [[ "${actual_weekday}" == "${weekday}" ]] || { printf 'bujo_migrate: weekday does not match date in %s\n' "${source}" >&2; return 2; }
            target="$(LC_ALL=C date -d "${iso_date} +1 day" '+%Y-%b-%-d-%a')" || return 1
            parent="${year}-${month}"
            [[ ! -f "${target}" ]] || _bujo_migrate_to "${source}" "${target}" '>' || return 1
            [[ ! -f "${parent}" ]] || _bujo_migrate_to "${source}" "${parent}" '<' || return 1
            ;;
        (*) printf 'bujo_migrate: unrecognized filename: %s\n' "${source}" >&2; return 2 ;;
    esac
}

_bujo_migrate_to() {
    local source="$1" target="$2" marker="$3" entries tmp
    [[ -f "${target}" ]] || return 0
    grep -q '^@MIGRATED@$' "${target}" || { printf 'bujo_migrate: placeholder @MIGRATED@ not found in %s\n' "${target}" >&2; return 1; }
    entries="$(awk -v marker="${marker}" '
        marker == "<" && /^[x~]/ { print; next }
        index($0, marker) == 1 { print "." substr($0, 2) }
    ' "${source}")"
    [[ -n "${entries}" ]] || return 0
    tmp="$(mktemp "${target}.XXXXXX")" || return 1
    if ! awk -v entries="${entries}" '
        BEGIN { n = split(entries, lines, "\n") }
        /^@MIGRATED@$/ {
            total = NR - 1
            for (i = 1; i <= n; i++) {
                duplicate = 0
                key = substr(lines[i], 2)
                for (j = 1; j <= total; j++) {
                    if (substr(seen[j], 1, 1) ~ /^[.x~]$/ && substr(seen[j], 2) == key) {
                        duplicate = 1
                        if (substr(lines[i], 1, 1) ~ /^[x~]$/ && substr(seen[j], 1, 1) == ".") {
                            seen[j] = substr(lines[i], 1, 1) substr(seen[j], 2)
                        }
                    }
                }
                if (!duplicate && substr(lines[i], 1, 1) !~ /^[x~]$/) seen[++total] = lines[i]
            }
            for (j = 1; j <= total; j++) print seen[j]
            print "@MIGRATED@"
            processed = 1
            next
        }
        !processed { seen[NR] = $0; next }
        { print }
    ' "${target}" >"${tmp}"; then rm -f "${tmp}"; return 1; fi
    if ! cat "${tmp}" >"${target}"; then rm -f "${tmp}"; return 1; fi
    rm -f "${tmp}"
    printf 'migrated entries from %s to %s\n' "${source}" "${target}"
}

