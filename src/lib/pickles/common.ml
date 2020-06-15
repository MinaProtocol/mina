open Core_kernel
open Pickles_types
module Rounds = Zexe_backend.Dlog_based.Rounds
module Unshifted_acc =
  Pairing_marlin_types.Accumulator.Degree_bound_checks.Unshifted_accumulators
open Import

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

let bits_random_oracle =
  let h = Digestif.blake2s 32 in
  fun ?(length = 256) s ->
    Digestif.digest_string h s |> Digestif.to_raw_string h |> String.to_list
    |> List.concat_map ~f:(fun c ->
           let c = Char.to_int c in
           List.init 8 ~f:(fun i -> (c lsr i) land 1 = 1) )
    |> fun a -> List.take a length

let bits_to_bytes bits =
  let byte_of_bits bs =
    List.foldi bs ~init:0 ~f:(fun i acc b ->
        if b then acc lor (1 lsl i) else acc )
    |> Char.of_int_exn
  in
  List.map (List.groupi bits ~break:(fun i _ _ -> i mod 8 = 0)) ~f:byte_of_bits
  |> String.of_char_list

let group_map m ~a ~b =
  let params = Group_map.Params.create m {a; b} in
  stage (fun x -> Group_map.to_group m ~params x)

let compute_challenge ~is_square x =
  let open Zexe_backend in
  let nonresidue = Fq.of_int 7 in
  let x = Endo.Dlog.to_field x in
  assert (is_square = Fq.is_square x) ;
  Fq.sqrt (if is_square then x else Fq.(nonresidue * x))

let compute_challenges chals =
  Vector.map chals ~f:(fun {Bulletproof_challenge.prechallenge; is_square} ->
      compute_challenge ~is_square prechallenge )
