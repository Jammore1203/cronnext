# cronnext

![CI](https://github.com/Jammore1203/cronnext/actions/workflows/ci.yml/badge.svg)

Explain a cron expression and list exactly when it will next fire. Written in Ada 2012 with no dependencies outside the standard library.

Use it to sanity-check a crontab line before deploying it.

```console
$ cronnext "*/15 9-17 * * MON-FRI" --from "2026-10-02 16:50"
minute    0,15,30,45
hour      9-17
day       any day
month     every month
weekday   Mon-Fri

next 5 runs after Fri 2026-10-02 16:50:
  Fri 2026-10-02 17:00
  Fri 2026-10-02 17:15
  Fri 2026-10-02 17:30
  Fri 2026-10-02 17:45
  Mon 2026-10-05 09:00
```

```console
$ cronnext "0 0 30 2 *"
...
cronnext: no matching time in the next five years

$ cronnext "61 * * * *"
cronnext: minute field "61": must be 0 to 59
```

## Usage

```
cronnext EXPRESSION [-n COUNT] [--from "YYYY-MM-DD HH:MM"]
```

`--from` defaults to the current local time.

### Supported syntax

| Feature | Example |
|---|---|
| Any value | `*` |
| Lists | `1,15,30` |
| Ranges | `9-17` |
| Steps | `*/15`, `10-50/10` |
| Names (any case) | `JAN-MAR`, `mon-fri` |
| Sunday as 0 or 7 | `0 0 * * 7` |
| Shortcuts | `@hourly` `@daily` `@midnight` `@weekly` `@monthly` `@yearly` `@annually` |

As in Vixie cron, when **both** day-of-month and day-of-week are restricted, a day matching **either** one fires. So `0 12 13 * FRI` runs on every Friday and on every 13th.

## Build

Needs GNAT (`apt install gnat`, `brew install gnat`, or [Alire](https://alire.ada.dev)).

```bash
make           # builds bin/cronnext
make test      # unit tests + CLI golden test
make install   # PREFIX=/usr/local by default
```

## Design

- `Cron.Parse` turns the expression into five boolean sets. Bad input raises `Parse_Error` with a message naming the field and the reason.
- `Cron.Next` works on a plain `Date_Time` record, not `Ada.Calendar.Time`, so scheduling is pure, has no time-zone dependency, and is easy to test. It skips whole non-matching months, days and hours, so even a yearly or leap-day match takes a few hundred steps.
- Day-of-week uses Sakamoto's method, and leap years follow the full Gregorian rule. The tests cover 1900 and 2000.
- Ada's range-constrained subtypes (`Hour_Number is 0 .. 23`, etc.) make an out-of-range date fail at the point it's created instead of producing a wrong answer later.
