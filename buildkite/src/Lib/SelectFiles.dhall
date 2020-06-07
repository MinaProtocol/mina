-- A DSL for representing file globbing; compiles into egrep-compatible regexp
let Prelude = ../External/Prelude.dhall
let P = Prelude

let PathPattern = < Lit : Text | Any > -- Any == *
let FilePattern = {
  Type = { dir: Optional (List PathPattern), exts: Optional (List Text) },
  default = { dir = None (List PathPattern), exts = None (List Text) }
}

let everything : FilePattern.Type = FilePattern.default

let contains : Text -> FilePattern.Type =
  \(s : Text) ->
  { dir = Some [PathPattern.Lit s],
    exts = None (List Text)
  }

let exactly : Text -> Text -> FilePattern.Type =
  \(dir : Text) -> \(ext : Text) ->
    { dir = Some [PathPattern.Lit dir],
      exts = Some [ext]
    }

-- compile things
let any : List Text -> Text =
  P.Text.concatSep "|"

let compileExt : Text -> Text =
  \(ext : Text) -> "\\." ++ ext ++ "\\\$"

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
    in
    let extPart =
      P.Optional.fold (List Text) pattern.exts Text compileExts ""
    in
    dirPart ++ extPart

let compile : List FilePattern.Type -> Text =
  \(patterns : List FilePattern.Type) ->
    let patterns_ = P.List.map FilePattern.Type Text compileFile patterns in
    any patterns_


let everythingExample = assert : compile [everything] === ".*"

let exactlyExample = assert : compile [exactly "scripts/compile" "py"] === "scripts/compile(\\.py\\\$)"

let containsExample = assert : compile [contains "buildkite/Makefile"] === "buildkite/Makefile"

let D = PathPattern
let realisticExample = assert : compile [
  FilePattern::{ dir = Some [D.Lit "buildkite/", D.Any], exts = Some ["dhall"] },
  contains "buildkite/Makefile",
  exactly "buildkite/scripts/generate-jobs" "sh"
] === "buildkite/.*(\\.dhall\\\$)|buildkite/Makefile|buildkite/scripts/generate-jobs(\\.sh\\\$)"


in
{ compile = compile,
  everything = everything,
  contains = contains,
  exactly = exactly,
  -- D for DSL
  PathPattern = PathPattern
} // FilePattern
