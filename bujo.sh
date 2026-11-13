# Create a year, month, or day journal file based on the number of arguments.
bujo_new() {
    case $# in
        1) _bujo_new_year "$@" ;;
        2) _bujo_new_month "$@" ;;
        3) _bujo_new_day "$@" ;;
        *)
            echo 'usage: bujo_new <year> [month [day]]' >&2
            return 2
            ;;
    esac
}

# Move marked tasks to the next period and, for months and days, their parent.
bujo_migrate() {
    local source="${1:-}" target parent year month day weekday iso_date actual_weekday

    if [[ -z "${source}" ]]; then
        echo 'usage: bujo_migrate <file>' >&2
        return 2
    fi
    if [[ ! -f "${source}" ]]; then
        printf 'bujo_migrate: source file not found: %s\n' "${source}" >&2
        return 1
    fi

    case "${source}" in
        ([0-9][0-9][0-9][0-9])
            target=$((10#${source} + 1))
            if [[ -f "${target}" ]]; then
                _bujo_migrate_to "${source}" "${target}" '>' || return 1
            fi
            ;;
        ([0-9][0-9][0-9][0-9]-[A-Z][a-z][a-z])
            year="${source%%-*}"
            month="${source#*-}"
            target="$(LC_ALL=C date -d "${month} 1 ${year} +1 month" '+%Y-%b')" || return 1

            if [[ -f "${target}" ]]; then
                _bujo_migrate_to "${source}" "${target}" '>' || return 1
            fi
            if [[ -f "${year}" ]]; then
                _bujo_migrate_to "${source}" "${year}" '<' || return 1
            fi
            ;;
        ([0-9][0-9][0-9][0-9]-[A-Z][a-z][a-z]-[0-9]-[A-Z][a-z][a-z]|[0-9][0-9][0-9][0-9]-[A-Z][a-z][a-z]-[0-9][0-9]-[A-Z][a-z][a-z])
            IFS=- read -r year month day weekday <<< "${source}"
            iso_date="$(LC_ALL=C date -d "${month} ${day} ${year}" '+%F' 2>/dev/null)" || return 2
            actual_weekday="$(LC_ALL=C date -d "${iso_date}" '+%a')" || return 1

            if [[ "${actual_weekday}" != "${weekday}" ]]; then
                printf 'bujo_migrate: weekday does not match date in %s\n' "${source}" >&2
                return 2
            fi

            target="$(LC_ALL=C date -d "${iso_date} +1 day" '+%Y-%b-%-d-%a')" || return 1
            parent="${year}-${month}"
            if [[ -f "${target}" ]]; then
                _bujo_migrate_to "${source}" "${target}" '>' || return 1
            fi
            if [[ -f "${parent}" ]]; then
                _bujo_migrate_to "${source}" "${parent}" '<' || return 1
            fi
            ;;
        (*)
            printf 'bujo_migrate: unrecognized filename: %s\n' "${source}" >&2
            return 2
            ;;
    esac
}

# Private helpers for bujo_new.
_bujo_new_year() {
    local year="${1:-}"

    if [[ -z "${year}" ]]; then
        echo 'usage: bujo_new <year>' >&2
        return 2
    fi
    LC_ALL=C date -d "Jan 1 ${year}" '+%Y' >/dev/null || return 1

    {
        printf '%d\n' "${year}"
        printf '. existing task\n@MIGRATED@\n'
        printf 'Jan\nFeb\nMar\nApr\nMay\nJun\nJul\nAug\nSep\nOct\nNov\nDec\n'
    } >"${year}"
    printf 'created %s\n' "${year}"
}

_bujo_new_month() {
    local year="${1:-}" month="${2:-}" short last_day filename day weekday

    if [[ -z "${year}" || -z "${month}" ]]; then
        echo 'usage: bujo_new <year> <month>' >&2
        return 2
    fi

    short="$(LC_ALL=C date -d "${month} 1 ${year}" '+%b')" || return 1
    last_day="$(LC_ALL=C date -d "${month} 1 ${year} +1 month -1 day" '+%d')" || return 1
    last_day=$((10#${last_day}))
    filename="${year}-${short}"

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
    local year="${1:-}" month="${2:-}" day="${3:-}" short weekday filename hour

    if [[ -z "${year}" || -z "${month}" || -z "${day}" ]]; then
        echo 'usage: bujo_new <year> <month> <day>' >&2
        return 2
    fi

    short="$(LC_ALL=C date -d "${month} ${day} ${year}" '+%b')" || return 1
    weekday="$(LC_ALL=C date -d "${month} ${day} ${year}" '+%a')" || return 1
    filename="${year}-${short}-${day}-${weekday}"

    {
        printf '%d %s %d %s\n. existing task\n@MIGRATED@\n' "${year}" "${short}" "${day}" "${weekday}"
        for ((hour = 8; hour <= 20; hour++)); do
            printf '%dH\n' "${hour}"
        done
    } >"${filename}"
    printf 'created %s\n' "${filename}"
}

# Private helper for moving matching tasks into a destination journal.
_bujo_migrate_to() {
    local source="$1" target="$2" marker="$3" entries tmp

    if [[ ! -f "${target}" ]]; then
        return 0
    fi
    if ! grep -q '^@MIGRATED@$' "${target}"; then
        printf 'bujo_migrate: placeholder @MIGRATED@ not found in %s\n' "${target}" >&2
        return 1
    fi

    entries="$(awk -v marker="${marker}" '
        marker == "<" && /^[x~]/ { print; next }
        index($0, marker) == 1 { print "." substr($0, 2) }
    ' "${source}")"
    if [[ -z "${entries}" ]]; then
        return 0
    fi

    tmp="$(mktemp "${target}.XXXXXX")" || return 1

    if ! awk -v entries="${entries}" '
        BEGIN {
            n = split(entries, lines, "\n")
        }

        /^@MIGRATED@$/ {
            total = NR - 1

            for (i = 1; i <= n; i++) {
                duplicate = 0
                key = substr(lines[i], 2)

                for (j = 1; j <= total; j++) {
                    is_task = substr(seen[j], 1, 1) ~ /^[.x~]$/
                    same_text = substr(seen[j], 2) == key

                    if (is_task && same_text) {
                        duplicate = 1
                        incoming_status = substr(lines[i], 1, 1)
                        existing_status = substr(seen[j], 1, 1)

                        if (incoming_status ~ /^[x~]$/ && existing_status == ".") {
                            seen[j] = incoming_status substr(seen[j], 2)
                        }
                    }
                }

                incoming_status = substr(lines[i], 1, 1)
                if (!duplicate && incoming_status !~ /^[x~]$/) {
                    seen[++total] = lines[i]
                }
            }

            for (j = 1; j <= total; j++) {
                print seen[j]
            }
            print "@MIGRATED@"
            processed = 1
            next
        }

        !processed {
            seen[NR] = $0
            next
        }

        {
            print
        }
    ' "${target}" >"${tmp}"; then
        rm -f "${tmp}"
        return 1
    fi

    if ! cat "${tmp}" >"${target}"; then
        rm -f "${tmp}"
        return 1
    fi
    rm -f "${tmp}"
    printf 'migrated entries from %s to %s\n' "${source}" "${target}"
}
