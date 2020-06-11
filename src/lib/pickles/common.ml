open Core_kernel
open Pickles_types
module Rounds = Zexe_backend.Dlog_based.Rounds

let crs_max_degree = 1 lsl Nat.to_int Rounds.n

let wrap_domains =
  { Domains.h= Pow_2_roots_of_unity 18
  ; k= Pow_2_roots_of_unity 18
  ; x= Pow_2_roots_of_unity 0 }

let when_profiling profiling default =
  match
    Option.map (Sys.getenv_opt "PICKLES_PROFILING") ~f:String.lowercase
  with
  | None | Some ("0" | "false") ->
      default
  | Some _ ->
      profiling

let time lab f =
  when_profiling
    (fun () ->
      let start = Time.now () in
      let x = f () in
      let stop = Time.now () in
      printf "%s: %s\n%!" lab (Time.Span.to_string_hum (Time.diff stop start)) ;
      x )
    f ()
