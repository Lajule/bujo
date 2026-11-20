# Bujo

`bujo` is a Bash script for creating and organizing journal files by year,
month, and day. Each file contains a task area followed by an `@MIGRATED@`
placeholder. The `bujo_migrate` function moves marked tasks to another period.

Load the script into the current shell to use its functions:

```bash
source ./bujo.sh
```

## Requirements

- A **Bash** shell (the functions are loaded into the current shell).
- **GNU coreutils**: the script relies on GNU `date -d` for date arithmetic,
  plus the standard `awk`, `grep`, `mktemp`, and `cat`.
- On macOS, install GNU tools (`brew install coreutils`) and make `gdate`
  available as `date` — for example by putting it first on your `PATH` — since
  the BSD `date` lacks `-d`.

## Creating files

### `bujo_new`

The number of arguments selects the kind of file to create:

- `bujo_new <year>` creates a file named for the year, such as `2026`. It
  contains a heading, a task area with the `@MIGRATED@` placeholder, and the
  twelve months.
- `bujo_new <year> <month>` creates a file named with the year and the month's
  English abbreviation, such as `2026-Feb`. It contains a heading, a task area,
  and a list of the month's days with their weekdays.
- `bujo_new <year> <month> <day>` creates a daily journal file named with the
  date and weekday, such as `2026-Feb-28-Sat`. It contains a heading, a task
  area, then hourly slots from `8H` through `20H`.

## Markers

In the task area, every line starts with a single prefix that decides what
happens to the task during migration:

| Marker    | Meaning |
| --------- | ------- |
| `. task`  | The task **stays here**: it is not moved by migration. It is also the prefix a task receives when it arrives from a finer period (from a day to its month, for example). |
| `> task`  | The task **follows the period**: a `>` in a day goes to the next day, in a month to the next month, in a year to the next year. |
| `< task`  | The task **moves up one level**: a `<` in a day goes up to its month, a `<` in a month goes up to its year. |
| `x task`  | A **completed** version of a task already present one level up: migration marks the original as done, without rewriting it. |
| `~ task`  | A **deferred** version of a task from the level above: the same as `x`, but to postpone it. |

Note: `x` and `~` only apply to tasks that already exist at the higher level.
If there is no matching task, they are simply ignored during migration —
never added.

## Migrating tasks

### `bujo_migrate <file>`

The argument is the name of an existing file. Migration looks for the expected
destination files in the current directory. If a destination does not exist,
it is skipped.

- **Year** — `bujo_migrate 2026` transfers lines in `2026` that start with `>` to
  the next year (`2027`). In the destination, the marker is replaced with `.`.
- **Month** — `bujo_migrate 2026-Feb` transfers lines starting with `>` to the next
  month (`2026-Mar`), and lines starting with `<` to the year file (`2026`).
- **Day** — `bujo_migrate 2026-Feb-28-Sat` transfers lines starting with `>` to the
  following day, and lines starting with `<` to the month file (`2026-Feb`).
  The weekday in the filename must match the date.

When migrating a month or day to its parent, lines starting with `x` or `~`
update the prefix of the matching task already present in the parent. They are
skipped when that task is absent, so they never create a new parent task.

Migrated `>` and `<` tasks are inserted where `@MIGRATED@` appears as lines
starting with `.`. Matching parent tasks are marked with the incoming `x` or
`~` prefix. The placeholder is retained for future migrations. Duplicate
migrated tasks and duplicates already present before the placeholder are
skipped.

## Example

Create a day and its two destinations, then seed the month with tasks that
already live there:

```bash
bujo_new 2026 Feb 28       # creates 2026-Feb-28-Sat
bujo_new 2026 Mar 1        # creates 2026-Mar-1-Sun
bujo_new 2026 Feb          # creates 2026-Feb
```

```text
# in 2026-Feb
2026 Feb
. send the monthly report
. fix the build
. plan the offsite
@MIGRATED@
```

Fill the day with a few tasks. The `x` and `~` lines close or postpone tasks
that already exist in the month:

```text
# in 2026-Feb-28-Sat
2026 Feb 28 Sat
> prepare the sprint review
< send the monthly report
x fix the build
~ plan the offsite
@MIGRATED@
8H
9H
```

Migrate this day:

```bash
bujo_migrate 2026-Feb-28-Sat
```

The `>` task is carried to the next day, the `<` task goes up to its month,
and the `x`/`~` lines update the matching tasks in the month. The day keeps
its placeholder for the next migration:

```text
# in 2026-Mar-1-Sun
2026 Mar 1 Sun
. existing task
. prepare the sprint review
@MIGRATED@

# in 2026-Feb
2026 Feb
. send the monthly report
x fix the build
~ plan the offsite
@MIGRATED@
```
