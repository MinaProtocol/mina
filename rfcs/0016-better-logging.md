# Better Logging

## Summary
[summary]: #summary

This RFC contains a proposal for a new logging system which will provide a better and more flexible format for our logging which can be easily processed by programs and is easy to construct into a human readable format.

## Motivation
[motivation]: #motivation

Our logs in a state where they are both hard to read and hard to process. To break down the individual issues with our logs:

- String escaping is broken
- Messages contain lots of data in the form of large serialized sexp, reducing readability
- No metadata is programmatically available without parsing the messages
- Existing tools (jq, rq) are very slow at processing the raw format of our logs
- Logs are very verbose, often containing redundant and unecessary information (long "paths", all logs are stamped with same info of host+pid which never changes across a single node)
- Lack of standard format or restrictions on length

This design attempts to address each of these issues in turn. If done correctly, we should be left with a logging format this is easily parsed by machines and can be easily formatted for parsing by humans.

## Detailed design
[detailed-design]: #detailed-design

### Format
[detailed-design-format]: #detailed-design-format

```json
{
  timestamp: timestamp,
  level: level,
  source: {
    module: string,
    location: string
  },
  message: format_string,
  metadata: {{...}}
}
```

The new format elides some of the previous fields, most notably host and pid. These can easily be decorated externally on a per log basis as these are really attributes of the node and never change across log messages. The new format also condenses the previous path section, which was used to store both the location based context and logger attributes. Instead, a single source is stored in the form of a module name and source location. The message is changed from a raw string into a special format string which can interpolate metadata stored inside of the logger message. The metadata field is an arbitrary json object which maps identifiers to any json value. Logging context is stored inside of metadata and can optionally be embeded into the message format string.

The format string for the message will support interpolation of the form `$<id>` where `<id>` is some key in `metadata`. A log processor should decide whether to embed or elide this information based on the length of the interpolation and the input of the user. More details on this are documented in the log processor section below.

### Logger Interface
[detailed-design-logger-interface]: #detailed-design-logger-interface

The logger interface will be changed slightly to support the new format. Most noticably, it will take an associative list of json values for the metadata field. It will also support the ability to derive a new logger with some added context, much like the old `Logger.child` system. However, rather than tracking source, this will allow for passing metadata down to log statements without explicitly providing them to the log function each time. The logger will check the correctness of the format string at compile time.

### Logging PPX
[detailed-design-logging-ppx]: #detailed-design-logging-ppx

The new logger interface is not as clean as the old one, requiring some of the same fields to be passed in over and over again in order to get source information available. It also only performs metadata interpolation checks at run time, where as some checks could be done at compile time. Furthermore, it now requires manual calls to json serialization functions. In order to alleviate these and make the interface nice, a PPX can be built.

For instance:

```ocaml
[%log_error logger "Error adding breadcrumb ${breadcrumb:Breadcrumb} to transition frontier: %s" [breadcrumb]]
  (Error.to_string err)
```

would translate to

```ocaml
Logger.error logger
  ~module:__MODULE__
  ~location:__LOC__
  ~metadata:[("breadcrumb", Breadcrumb.to_yojson breadcrumb)]
  "Error adding breadcrumb $breadcrumb to transition frontier: %s"
  (Error.to_string err)
```

which would produce a log like (where the `<>`'s are replaced)

```json
{
  timestamp: <now>,
  level: "error",
  source: {
    module: "<__MODULE__>",
    location: "<__loc__>"
  },
  message: "Error adding breadcrumb $breadcrumb to transition frontier: <err>",
  metadata: {
    breadcrumb: {<breadcrumb...>},
    <context...>
  }
}
```

and would be formatted as

```
Error adding breadcrumb {...} to transition frontier: <err>
```

### Log Processor
[detailed-design-log-processor]: #detailed-design-log-processor

While the logging format is still in json, meaning that programs such as `jq` et al. can be used to process logs, this has been too slow in practice. Specifically, in the case of `jq`, there is limited support for handling files full of multiple json objects (statically or streaming), so `jq` needs to be reinvoked for every line in the log, which involves re-parsing and processing filter expressions for each log entry. Instead, we will go back to writing our own log processor utility. This makes additional sense in the context that we want to perform and configure interpolation for our log messages.

The log processor should support some basic configuration to control how interpolation of the message string is performed. For instance, the default could be to attempt to keep all message under a specific length (say `< 80`) and to elide interpolation otherwise. Another option could be to constrain a max length of the interpolated value, or even constrain interpolation by the type of the value (for instance, elide all objects and interpolate other values). And yet another would be to just always interpolate the entire values, or print messages in a raw format with the relevant metadata displayed below the message. These various options should be added as they are needed by developers, so I will not lay out the specific requirements here.

The log processor should support a simple `jq`-esque filter language. The scope of this is *significantly* smaller than that of `jq` as it only needs the ability to form simple predicates on a json object. An example of what this language could look like is speced out below in BNF. It mostly follows javascript syntax with little divergence, except that it is much more constrained in scope. The toplevel rule is `<bool_exp>` since this is a filter language.

```bnf
<bool> ::= "true" | "false"

<digit> ::= "0".."9"
<integer> ::= <digit> | <integer> <digit>

<alpha> ::= "a".."z" | "A".."Z" | "_"
<char> ::= <alpha> | "0" .. "9"
<escape> ::= '"' | '\' | '/' | 'b' | 'n' | 'r' | 't'
<text> ::= "" | '\' <escape> <text> | <char> <text>
<string> ::= '"' <text> '"'

<ident> ::= <alpha> <text>

<literal> ::= <bool> | <integer> | <string>
<access_exp> ::= "." <ident> | "[" <string> "]" | "[" <integer> "]"
<value_exp> ::= <literal> | <access_exp> | "(" <value_exp> ")"

<compare_op> ::= "===" | "!=="
<compare_exp> ::= <value_exp> <compare_op> <value_exp>

<bin_bool_op> ::= "&&" | "||"
<bool_exp> ::= <bool> | <compare_exp> | "!" <bool_exp> | <bool_exp> <bin_bool_op> <bool_exp> | "(" <bool_exp> ")"
```

Unsupported features:
- unicode escapes (`"\u235f"`)
- non strict equality (`==`, `!=`)
- object/array literals (`{some: "object"}`, `[1, 2, 3]`)
- bindings (`let x = ... in x + 1` or some more js style form)

*NOTES: syntax currently does not support single quoted strings*

## Drawbacks
[drawbacks]: #drawbacks

This format is much more verbose than raw text logs, though this was true with our old logging format as well. I believe we are more concerned about the machine parsability of logs than we are about smaller logs.

## Prior art
[prior-art]: #prior-art

Before our current format, we had a sexp style format with a custom log processor. That system was not perfect for a few reasons, and this RFC attempts to take the good parts of that setup and fix some of the nasty parts. In particular, this RFC attempts to layout a more approachable filter language and an easier to process form of metadata (formerly known as attributes).

## Unresolved questions
[unresolved-questions]: #unresolved-questions

- How much work will the PPX be to create? Is there a way we can fully validate that a message only interpolates known values at any point in the context (perhaps by modeling metadata inheritence)?
- Is the filter language sufficient enough for our needs?
