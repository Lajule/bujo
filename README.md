# Bujo

`bujo` is a Bash script for creating and organizing journal files by year,
month, and day. Each file contains a task area followed by an `@MIGRATED@`
placeholder. The `bujo_migrate` function moves marked tasks to another period.

Load the script into the current shell to use its functions:

```bash
source ./bujo.sh
```

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
