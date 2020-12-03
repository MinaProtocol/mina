-- A DSL for representing file globbing; compiles into egrep-compatible regexp
let Prelude = ../External/Prelude.dhall
let P = Prelude

let PathPattern = < Lit : Text | Any > -- Any == *
let FilePattern = {
  Type = {
    dir: Optional (List PathPattern),
    exts: Optional (List Text),
    strictStart: Bool,
    -- strictEnd implicitly set if exts is present
    strictEnd: Bool
  },
  default = {
    dir = None (List PathPattern),
    exts = None (List Text),
    strictStart = False,
    strictEnd = False
  }
}


let strictlyStart : FilePattern.Type -> FilePattern.Type =
  \(pattern : FilePattern.Type) -> pattern // { strictStart = True }

let strictlyEnd : FilePattern.Type -> FilePattern.Type =
  \(pattern : FilePattern.Type) -> pattern // { strictEnd = True }

let strictly : FilePattern.Type -> FilePattern.Type =
  \(pattern : FilePattern.Type) -> strictlyEnd (strictlyStart pattern)

let everything : FilePattern.Type = FilePattern.default

let contains : Text -> FilePattern.Type =
  \(s : Text) ->
  FilePattern::{ dir = Some [PathPattern.Lit s] }

let exactly : Text -> Text -> FilePattern.Type =
  \(dir : Text) -> \(ext : Text) ->
    FilePattern::{
      dir = Some [PathPattern.Lit dir],
      exts = Some [ext],
      strictStart = True,
      strictEnd = True
    }

-- compile things
let any : List Text -> Text =
  P.Text.concatSep "|"

let compileExt : Text -> Text =
  \(ext : Text) -> "\\." ++ ext

let compileExts : List Text -> Text =
  \(exts : List Text) ->
    let exts_ = P.List.map Text Text compileExt exts in
    "(" ++ (any exts_) ++ ")"

let compilePath : PathPattern -> Text =
  \(path : PathPattern) ->
    merge {
      Lit = \(text : Text) -> text,
      Any = ".*"
    } path

let compilePaths : List PathPattern -> Text =
  \(paths : List PathPattern) ->
    let paths_ = P.List.map PathPattern Text compilePath paths in
    P.Text.concat paths_

let compileFile : FilePattern.Type -> Text =
  \(pattern : FilePattern.Type) ->
    let dirPart =
      P.Optional.fold (List PathPattern) pattern.dir Text compilePaths ".*"
    let extPart =
      P.Optional.fold (List Text) pattern.exts Text compileExts ""
    let startPart =
      if pattern.strictStart then "^" else ""
    let endPart =
      if pattern.strictEnd || (P.Bool.not (P.Optional.null (List Text) pattern.exts)) then
        "\\\$"
      else
        ""
    in
    startPart ++ dirPart ++ extPart ++ endPart

let compile : List FilePattern.Type -> Text =
  \(patterns : List FilePattern.Type) ->
    let patterns_ = P.List.map FilePattern.Type Text compileFile patterns in
    any patterns_


let everythingExample = assert : compile [everything] === ".*"

let exactlyExample = assert : compile [exactly "scripts/compile" "py"] === "^scripts/compile(\\.py)\\\$"

let containsExample = assert : compile [contains "buildkite/Makefile"] === "buildkite/Makefile"

let strictContainsExample = assert : compile [strictly (contains "buildkite/Makefile")] === "^buildkite/Makefile\\\$"

let D = PathPattern
let realisticExample = assert : compile [
  strictly (FilePattern::{
    dir = Some [D.Lit "buildkite/", D.Any],
    exts = Some ["dhall"]
  }),
  strictly (contains "buildkite/Makefile"),
  exactly "buildkite/scripts/generate-jobs" "sh"
] === "^buildkite/.*(\\.dhall)\\\$|^buildkite/Makefile\\\$|^buildkite/scripts/generate-jobs(\\.sh)\\\$"


in
{ compile = compile,
  everything = everything,
  contains = contains,
  exactly = exactly,
  strictlyStart = strictlyStart,
  strictlyEnd = strictlyEnd,
  strictly = strictly,
  -- D for DSL
  PathPattern = PathPattern
} // FilePattern
