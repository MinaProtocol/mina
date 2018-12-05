open Core

module Rollback = struct
  type t = Do_nothing | Call of (unit -> unit)

  let compose t1 t2 =
    match (t1, t2) with
    | Do_nothing, t | t, Do_nothing -> t
    | Call f1, Call f2 -> Call (fun () -> f1 () ; f2 ())

  let run = function Do_nothing -> () | Call f -> f ()
end

module T = struct
  type 'a result = {result: 'a Or_error.t; rollback: Rollback.t}

  type 'a t = 'a result

  let return x = {result= Ok x; rollback= Do_nothing}

  let bind tx ~f =
    Monad.Ident.bind tx ~f:(fun {result; rollback} ->
        match result with
        | Error e -> Monad.Ident.return {result= Error e; rollback}
        | Ok x ->
            Monad.Ident.map (f x) ~f:(fun ty ->
                { result= ty.result
                ; rollback= Rollback.compose rollback ty.rollback } ) )

  let map t ~f =
    Monad.Ident.map t ~f:(fun res ->
        {res with result= Or_error.map ~f res.result} )

  let map = `Custom map
end

include T
include Monad.Make (T)

let run t =
  Monad.Ident.map t ~f:(fun {result; rollback} ->
      (match result with Error _ -> Rollback.run rollback | Ok _ -> ()) ;
      result )

let error e = Monad.Ident.return {result= Error e; rollback= Do_nothing}

let of_or_error result = Monad.Ident.return {result; rollback= Do_nothing}

let with_no_rollback dresult =
  Monad.Ident.map dresult ~f:(fun result -> {result; rollback= Do_nothing})
