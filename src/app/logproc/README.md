Logproc
=======

The `logproc` utility is a specialized log processor for Mina logs. It reads
JSON log entries from standard input, filters them based on user-specified
criteria, and displays them in a readable, colorized format. This tool is
invaluable for developers and operators who need to analyze Mina node logs
efficiently.

Features
--------

- Filters log entries using a JavaScript-like query language
- Colorizes output based on log levels for better readability
- Interpolates message templates with their metadata
- Controls how and where interpolated values appear
- Maintains original timestamps with configurable timezone support
- Processes logs in streaming fashion, suitable for large log files

Prerequisites
------------

Logproc is designed to work with Mina's JSON-formatted logs. To use it
effectively, you need:

1. Log output from a Mina node, typically generated when running the node with
   `--json` flag
2. Basic understanding of the filtering syntax to isolate relevant log entries

Compilation
----------

To compile the `logproc` executable, run:

```shell
$ dune build src/app/logproc/logproc.exe --profile=dev
```

The executable will be built at:
`_build/default/src/app/logproc/logproc.exe`

Usage
-----

The basic syntax for running `logproc` is:

```shell
$ logproc [OPTIONS]
```

Typically, logproc is used in a pipeline where Mina logs are streamed to its
standard input:

```shell
$ cat mina.log | logproc
```

or

```shell
$ mina daemon --json | logproc
```

### Command Line Options

- `-f, --filter FILTER`: Filter displayed log lines using the query language
- `-i, --interpolation-mode MODE`: Set how interpolation is performed
  (valid options: "hidden", "inline", "after", default: "inline")
- `-m, --max-interpolation-length LENGTH`: Maximum allowed length of interpolated
  values (default: 25)
- `-p, --pretty-print`: Pretty print JSON values
- `-z, --zone TIMEZONE`: Timezone to display timestamps in (default: system timezone)
- `--version`: Show version information
- `--help`: Show help text

### Filter Syntax

The filter language has similar syntax to JavaScript, with a few notable
differences:

- Access a field using `.fieldname` or `["fieldname"]` (like in jq)
- Use `==` for equality comparisons (not `===` as in JavaScript)
- Use `!`, `&&`, and `||` for logical operations
- Use `in` to check if a value exists in an array
- Use regex with `/pattern/` and the `match` operator

Filter expressions operate on the JSON structure of each log entry. The most
common fields are:

- `.level`: Log level (Spam, Trace, Debug, Info, Warn, Error, Faulty_peer, Fatal)
- `.message`: The log message text
- `.timestamp`: The timestamp of the log entry
- `.source.module`: The module that generated the log
- `.metadata`: Additional structured data for the log entry

Examples
--------

Display all logs with default settings:

```shell
$ cat mina.log | logproc
```

Show only Warning, Error, and Fatal log entries:

```shell
$ cat mina.log | logproc -f '.level in ["Warn", "Error", "Fatal"]'
```

Show logs from a specific module:

```shell
$ cat mina.log | logproc -f '.source.module == "Gossip_net"'
```

Filter logs containing specific text using regex:

```shell
$ cat mina.log | logproc -f '.message match /block producer/'
```

Combined complex filter:

```shell
$ cat mina.log | logproc -f '.level in ["Error", "Fatal"] && (.message match /timeout/ || .message match /disconnect/)'
```

Show all log metadata after each message:

```shell
$ cat mina.log | logproc -i after
```

Pretty print JSON values in logs:

```shell
$ cat mina.log | logproc -p
```

Use a specific timezone for timestamps:

```shell
$ cat mina.log | logproc -z "America/Los_Angeles"
```

Technical Notes
--------------

- The tool processes logs line by line, expecting each line to be a valid JSON
  object created by the Mina logging system.

- Lines that don't start with '{' (not valid JSON) are passed through with the
  prefix "!!! " to distinguish them from processed log entries.

- The timestamp format is "YYYY-MM-DD HH:MM:SS.ms" in the specified timezone.

- Log levels are color-coded for easier visual scanning:
  - Spam/Trace/Internal: Cyan
  - Debug: Green
  - Info: Magenta 
  - Warn: Yellow
  - Error: Red
  - Faulty_peer: Orange
  - Fatal: Bright Red

- Interpolation modes determine how template variables in log messages are
  handled:
  - "inline": Replace variables directly in the message (default)
  - "after": Show the raw message followed by each variable's value
  - "hidden": Don't show variable values, just the raw message

- The tool handles partial reads efficiently, making it suitable for processing
  large log files or continuous log streams.

Advanced Usage
-------------

### Integration with Other Tools

Logproc works well with other command-line tools:

```shell
# Count errors by type
$ cat mina.log | logproc -f '.level == "Error"' | grep -oP 'Error.*?:' | sort | uniq -c

# Monitor logs in real-time with color
$ tail -f mina.log | logproc

# Save filtered logs to a file while watching them
$ mina daemon --json | tee full.log | logproc -f '.level in ["Warn", "Error"]' | tee -a issues.log
```

### Using with systemd

For systems using systemd, you can pipe journalctl output through logproc:

```shell
$ journalctl -u mina -f -o json | logproc
```