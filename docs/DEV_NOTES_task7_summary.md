# Development Note: Task 7, Archive Summary in the Log

**Script:** `sysaudit_summary.sh` · **Config keys:** `AUDIT_DIR`, `ARCHIVE_EXTENSIONS` (and optional `ARCHIVE_DIR`) · **Author:** Felix Tu · **Date:** 2026-10-30

Textbook: Nemeth et al., *UNIX and Linux System Administration Handbook*, 5th edition (2018). Page numbers below are the printed page numbers. In the PDF copy, add 47.

## What the task asks for

Every time the archive step runs, write one summary line to the log with:
- the number of compressed archives in the folder,
- the name of the largest one,
- its size in bytes,
- its modification timestamp.

## How I built it

1. **Loop over the archives.** I used a `for ... in` loop over a filename pattern, like the `for script in *.sh` example on p. 207. The archive types come from the config (`ARCHIVE_EXTENSIONS=tar.gz,zip`), so there is an outer loop over the types and an inner loop over the files. The book notes that filenames with spaces still go through this kind of loop as one name (p. 207, footnote 13).
2. **Which folder.** The function looks in `AUDIT_DIR`, the team's shared key. If task 3 ends up saving archives somewhere else, setting `ARCHIVE_DIR` in `sysaudit.cfg` is enough; no code change is needed.
3. **Skip the pattern when nothing matches.** If a folder has no `.zip` files, bash leaves the pattern `*.zip` as it is. `[ -f "$file" ] || continue` skips it.
4. **Read the size and time.** The book shows that `ls -l` lists the size in bytes and the date of last modification (pp. 134 to 135). `ls` output is hard to parse in a script and only shows minutes, so I used `stat -c %s` (size) and `stat -c %y` (modification time with fractions of a second). These are the same two pieces of information.
5. **Why modification time.** The book points out that "ctime" is **not** the creation time; it is the time the file's attributes changed (p. 134). An archive is written once and never changed, so its modification time is the moment it was created.
6. **Counting and finding the largest.** I count with `$((count + 1))` (p. 208) and compare sizes with `-gt` (Table 7.3, p. 205).
7. **Error check.** If the folder doesn't exist (`-d`, Table 7.4, p. 206), the function logs an `[ERROR]` and returns 4. It doesn't crash the daemon.

## How it runs

It is called once per archive cycle, after task 3 (compress) and task 6 (delete old archives). Output from a test run:

```
2026-10-30 10:10:52 [INFO] sysaudit[13474]: Archive summary: 3 archives in /course_project/audit, largest is audit_2026-10-27.tar.gz (10240 bytes, modified 2026-10-27 00:00:04.000000000 -0700)
```

(The fraction of a second is `.000000000` only because the test set the time with `touch -d`.)

Return codes: `0` ok · `4` archive folder missing.

## Textbook pages used

| What I used | Page |
|---|---|
| Comment block at the top of the script | 188 |
| `for ... in` loop over files matching a pattern | 207 |
| `$((...))` arithmetic | 208 to 209 |
| `-gt`, `-eq`, `-z` comparisons | 205 (Table 7.3) |
| `-d`, `-f` file tests | 206 (Table 7.4) |
| `ls -l` shows size in bytes and last modification date | 134 to 135 |
| ctime is not the creation time | 134 |
| Command substitution `$(...)` / backquotes | 193 |

Not from the book: the `stat -c` format codes, `basename`, and `${ARCHIVE_EXTENSIONS//,/ }` to split the comma list.

## How to add it to the main script

```bash
source "$SCRIPT_DIR/sysaudit_logger.sh"      # must come first
source "$SCRIPT_DIR/sysaudit_summary.sh"

# at the end of each cleanup cycle:
archive_files          # task 3
delete_old_archives    # task 6
archive_summary        # task 7
```

## Testing

`bash tests/test_tasks_5_7_8.sh` runs 7 tests for task 7:
- only the 3 archives are counted (a bigger `.audit` file is ignored);
- the right largest file, exact bytes and modification time are logged;
- an empty folder gives 0;
- a missing folder returns 4.

All passed on 2026-10-30.
