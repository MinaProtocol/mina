(* type 'a result =
  | Success of string option * 'a
  | HardError of string
  | SoftError of string * 'a

type ('a, 'b) err_accumulator =
  {log: string list; res: 'a result; already_hit_hard: bool} *)

open Core_kernel

(* open Error *)
open Async_kernel

(* open Result *)
(* open Base *)
(* open Stdio *)

module Hard_fail = struct
  type t = {hard_error: Error.t; soft_errors: Error.t list}
end

module Accumulator = struct
  type 'a t = {computation_result: 'a; soft_errors: Error.t list}
end

module ErrorReporting = Monad.Make (struct
  type 'a t = ('a Accumulator.t, Hard_fail.t) Deferred.Result.t

  let return a =
    Deferred.return (Ok {Accumulator.computation_result= a; soft_errors= []})

  let bind res ~f =
    match%bind res with
    | Ok {Accumulator.computation_result= prev_result; soft_errors= err_list}
      -> (
        let execProg = f prev_result in
        match%bind execProg with
        | Ok {Accumulator.computation_result= comp; soft_errors= next_list} ->
            Deferred.return
              (Ok
                 { Accumulator.computation_result= comp
                 ; Accumulator.soft_errors= List.append err_list next_list })
        | Error
            {Hard_fail.hard_error= hard_err; Hard_fail.soft_errors= err_list}
          ->
            Deferred.return
              (Error {Hard_fail.hard_error= hard_err; soft_errors= err_list}) )
    | Error {Hard_fail.hard_error= hard_err; Hard_fail.soft_errors= err_list}
      ->
        Deferred.return
          (Error
             {Hard_fail.hard_error= hard_err; Hard_fail.soft_errors= err_list})

  let map = `Define_using_bind
end)

(* 

let%test_unit "error_monad_unit_test" =
let open Some_monad.Let_syntax in
  let test1 =
    let f nm =
      let%bind n = nm in
      Ok {computation_result= n + 1; soft_errors= []}
    in
    f (f (f (f (f (return 0)))))
  in
  assert (test1 = Ok {computation_result= 5; soft_errors= []})

let test2 =
  let%bind () = Ok {result= (); soft_errors= []} in
  Ok {result= "123"; soft_errors= []}

let () = assert (test2 = Ok {result= "123"; soft_errors= []})

let test3 =
  let%bind () = Ok {result= (); soft_errors= [Error.of_string "a"]} in
  Ok {result= "123"; soft_errors= [Error.of_string "b"]}

let () =
  assert (
    match test3 with
    | Ok {result= "123"; soft_errors} ->
        ["a"; "b"] = List.map soft_errors ~f:Error.to_string_hum
    | _ ->
        false )

let test4 =
  let%bind () = Ok {result= (); soft_errors= []} in
  Error {hard_error= Error.of_string "xyz"; soft_errors= []}

let () =
  assert (
    match test4 with
    | Error {hard_error; soft_errors= []} ->
        "xyz" = Error.to_string_hum hard_error
    | _ ->
        false )

let test5 =
  let%bind () = Ok {result= (); soft_errors= [Error.to_string_hum "a"]} in
  Error {hard_error= Error.of_string "xyz"; soft_errors= []}

let () =
  assert (
    match test5 with
    | Error {hard_error; soft_errors= [soft_error]} ->
        "xyz" = Error.to_string_hum hard_error
        && "a" = Error.to_string_hum soft_error
    | _ ->
        false )

let test6 =
  let%bind () = Ok {result= (); soft_errors= [Error.to_string_hum "a"]} in
  Error
    {hard_error= Error.of_string "xyz"; soft_errors= [Error.to_string_hum "b"]}

let () =
  assert (
    match test6 with
    | Error {hard_error; soft_errors} ->
        "xyz" = Error.to_string_hum hard_error
        && ["a"; "b"] = List.map soft_errors ~f:Error.to_string_hum
    | _ ->
        false ) *)

(* 

let return fv v = {log= []; res= fv v; already_hit_hard= false}

let bind acc fnc =
  match acc.res with
  | Success (Some message, a) ->
      let message_modified = Format.sprintf "INFO: %s" message in
      let execProg = fnc a in
      { log= List.append (List.append acc.log [message_modified]) execProg.log
      ; res= execProg.res
      ; already_hit_hard= false }
  | Success (None, a) ->
      let execProg = fnc a in
      { log= List.append acc.log execProg.log
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
      else {log= acc.log; res= HardError message; already_hit_hard= true} *)
