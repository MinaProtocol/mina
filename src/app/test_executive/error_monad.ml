type 'a result =
  | Success of string * 'a
  | HardError of string
  | SoftError of string * 'a

type ('a, 'b) err_accumulator =
  {log: string list; res: 'a result; already_hit_hard: bool}

let return fv v = {log= []; res= fv v; already_hit_hard= false}

let bind acc fnc =
  match acc.res with
  | Success (message, a) ->
      let message_modified = Format.sprintf "INFO: %s" message in
      let execProg = fnc a in
      { log= List.append (List.append acc.log [message_modified]) execProg.log
      ; res= execProg.res
      ; already_hit_hard= false }
  | SoftError (message, a) ->
      let message_modified = Format.sprintf "SOFT ERROR: %s" message in
      let execProg = fnc a in
      { log= List.append (List.append acc.log [message_modified]) execProg.log
      ; res= execProg.res
      ; already_hit_hard= false }
  | HardError message ->
      if not acc.already_hit_hard then
        let message_modified = Format.sprintf "HARD ERROR: %s" message in
        { log= List.append acc.log [message_modified]
        ; res= HardError message
        ; already_hit_hard= true }
      else {log= acc.log; res= HardError message; already_hit_hard= true}

(*
module Main where

import Text.Printf


data Result val = Success (Maybe String) val | HardError String | SoftError String val

data Error_accumulator val = Error_accumulator {accumulator :: [String],
                                                res :: Result val,
                                                alreadyHitHard :: Bool}


return :: (v -> Result v) -> (v -> Error_accumulator v)
return fv = \v -> (Error_accumulator [] (fv v) False)


(>>=) :: Error_accumulator v -> (v -> Error_accumulator u) -> Error_accumulator u
(>>=) previousLine restOfProg =
    case previousLine of
        Error_accumulator strList (Success (Just message) a ) _ ->
            let message_modified = "INFO: "++message in
            let execProg = restOfProg a in
            Error_accumulator (strList ++[message_modified] ++ (accumulator execProg) )
                                (res execProg)
                                False
        Error_accumulator strList (Success Nothing a ) _ ->
            let execProg = restOfProg a in
            Error_accumulator (strList)
                                (res execProg)
                                False


        Error_accumulator strList (SoftError message a ) _ ->
            let message_modified = "SOFT ERROR: "++message in
            let execProg = restOfProg a in
            Error_accumulator ( strList ++[message_modified] ++ (accumulator execProg))
                                (res execProg)
                                False

        Error_accumulator strList (HardError message) ahh ->
            if not ahh then
                let message_modified = "HARD ERROR: "++message in
                Error_accumulator (strList ++ [message_modified] )
                                    (HardError message)
                                    True --error message_modified
            else
                Error_accumulator strList
                                    (HardError message)
                                    ahh


 *)
