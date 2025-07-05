-- This package provides utility functions which are not part of the
-- standard Prelude, such as `join` for concatenating lists of text with a separator.

let Prelude = ../External/Prelude.dhall

let List/concatMap = Prelude.List.concatMap

let List/drop = Prelude.List.drop

let List/fold_ = Prelude.List.fold

let Text/concat = Prelude.Text.concat

let join =
          \(sep : Text)
      ->  \(xs : List Text)
      ->  let concatWithSepAtStart =
                List/concatMap Text Text (\(item : Text) -> [ sep, item ]) xs

          let concat = List/drop 1 Text concatWithSepAtStart

          in  Text/concat concat

let joinOptionals
    : List (Optional Text) -> Optional Text
    =     \(xs : List (Optional Text))
      ->  List/fold_
            (Optional Text)
            xs
            (Optional Text)
            (     \(acc : Optional Text)
              ->  \(x : Optional Text)
              ->  merge
                    { Some =
                            \(text : Text)
                        ->  merge
                              { None = Some text
                              , Some =
                                  \(accText : Text) -> Some (accText ++ text)
                              }
                              acc
                    , None = acc
                    }
                    x
            )
            (None Text)

in  { join = join, joinOptionals = joinOptionals }
