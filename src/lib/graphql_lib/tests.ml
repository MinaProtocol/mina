(** Tests that the custom scalars defined in the Scalars module,
    the coerce function used by the GraphQL server is the inverse of the parse function
    (which is used by graphql_ppx to decode the responses).
 *)

open Core_kernel
open Async_kernel
open Async_unix
module Schema = Graphql_wrapper.Make (Graphql_async.Schema)

let test_query schema ctx query f : unit =
  Thread_safe.block_on_async_exn (fun () ->
      match Graphql_parser.parse query with
      | Error err ->
          failwith err
      | Ok doc ->
          Graphql_async.Schema.execute schema ctx doc
          >>= (function
                | Ok (`Response data) ->
                    Async_kernel.return data
                | Ok (`Stream stream) ->
                    Async_kernel.Pipe.to_list stream
                    >>| fun lst ->
                    `List
                      Core_kernel.(
                        List.map lst ~f:(fun x ->
                            Option.value_exn (Result.ok x) ))
                | Error err ->
                    Async_kernel.return err )
          >>| f )

module type GENERATOR = sig
  type t

  val gen : t Base_quickcheck.Generator.t

  val sexp_of_t : t -> Ppx_sexp_conv_lib.Sexp.t

  val compare : t -> t -> int
end

let get_test_field = function
  | `Assoc [ ("data", `Assoc [ ("test", value) ]) ] ->
      value
  | _ ->
      failwith "asdasd"

module Make_test (S : Scalars.S_JSON) (G : GENERATOR with type t = S.t) = struct
  (** Builds a test which creates a schema returning a value of type [S.t],
      query it, parse the response back from JSON and compare the values. *)
  let query_server_and_compare value =
    let () = Format.printf "before print\n" in
    let () =
      Format.printf "calling test with value %s\n"
        (G.sexp_of_t value |> Sexp.to_string)
    in
    let () = Format.printf "after print\n" in
    ()
  (* let _:string = Format.flush_str_formatter () in *)
  (* let schema = *)
  (*   Graphql_async.Schema.( *)
  (*     schema *)
  (*       [ field "test" *)
  (*           ~typ:(non_null @@ S.typ ()) *)
  (*           ~args:Arg.[] *)
  (*           ~resolve:(fun _ () -> value) *)
  (*       ]) *)
  (* in *)
  (* test_query schema () "{ test }" (fun response -> *)
  (*     [%test_eq: G.t] value (S.parse @@ get_test_field response) ) *)

  let%test_unit "test" =
    Quickcheck.test G.gen ~sexp_of:G.sexp_of_t ~f:query_server_and_compare
end

(* let%test_module "BlockTime" = (module Make_test (Scalars.BlockTime) (Block_time)) *)

(* let%test_module "EpochSeed" = *)
(*   (module Make_test (Scalars.EpochSeed) (Mina_base.Epoch_seed)) *)

(* let%test_module "Fee" = (module Make_test (Scalars.Fee) (Currency.Fee)) *)

(* let%test_module "Amount" = (module Make_test (Scalars.Amount) (Currency.Amount)) *)

(* let%test_module "TokenId" = *)
(*   (module Make_test (Scalars.TokenId) (Mina_base.Token_id)) *)

(* let%test_module "Balance" = *)
(*   (module Make_test (Scalars.Balance) (Currency.Balance)) *)

(* let%test_module "PublicKey" = *)
(*   (module Make_test (Scalars.PublicKey) (Signature_lib.Public_key.Compressed)) *)

(* let%test_module "Uint64" = (module Make_test(Scalars.UInt64)(Unsigned.UInt64)) *)
(* let%test_module "Uint32" = (module Make_test(Scalars.UInt32)(Unsigned.UInt32)) *)

module Time_gen = struct
  (* type t = Core.Time.t *)
  type t = Core_kernel.Time.t

  (* let gen = Core.Time.quickcheck_generator *)
  (* let gen = Core_kernel.Time.quickcheck_generator *)
  let gen = Core_kernel.Time.quickcheck_generator

  (* We generate spans up to (slightly more than) a millenium, positive or negative. This
     is based on the Gregorian calendar, in which years average 365.2425 days when
     accounting for leap days. Covering a two-millenium span is more than enough for most
     practical purposes, certainly more than enough to cover the representable range of
     [Span_ns], and results in finite spans and times that can be serialized.

     We generate by filtering the default generator so that spans are still skewed toward
     small values, even though the bounds are large. *)
  (*   let millenium = of_day (Float.round_up (365.2425 *. 1000.)) in *)
  (*   Quickcheck.Generator.filter Core_kernel.Time.quickcheck_generator ~f:(fun t -> *)
  (*     neg millenium <= t && t <= millenium) *)
  (* ;; *)

  (* let sexp_of_t = Core.Time.sexp_of_t *)
  let sexp_of_t t = Sexp.Atom (Core_kernel.Time.to_string t)

  let compare x y =
    (* let () = Format.printf "\nx=%s\ny=%s\ncompare=%d\n equal=%b" (Core_kernel.Time.to_string x) (Core_kernel.Time.to_string y) (Core.Time.compare y x) (Core.Time.equal x y) in *)
    (* Core.Time.compare y x *)
    (* Core_kernel.Time.robustly_compare x y *)
    (* Core.Time.robustly_compare x y *)
    Core_kernel.Time.robustly_compare x y
  (* Stdlib.compare  x y *)
end

(* let%test_module "Time" = (module Make_test (Scalars.Time) (Time_gen)) *)

let%test_unit "Time test" =
  (* let () = Printexc.record_backtrace true in *)
  let gen = Core_kernel.Time.quickcheck_generator in
  let sexp_of t = Core.Time.sexp_of_t t in
  Quickcheck.test gen ~sexp_of ~f:(fun t ->
      ignore @@ Core_kernel.Time.to_string t )

(* let%test_unit "block Time test" = *)
(*   let gen = Block_time.gen in *)
(*   let sexp_of t = Block_time.sexp_of_t t in *)
(*   (\* Quickcheck.test gen ~sexp_of ~f:(fun t -> ignore @@ Core_kernel.Time.to_string t) *\) *)
(*   (\* Quickcheck.test gen ~sexp_of ~f:(fun t -> ignore (Block_time.to_string t: string)) *\) *)
(*   (\* Quickcheck.test gen ~sexp_of ~f:(fun t -> ignore (Block_time.to_time t: Core_kernel.Time.t)) *\) *)
(*   (\* Quickcheck.test gen ~sexp_of ~f:(fun t -> ignore (Block_time.to_time t |> Core.Time.to_string : string)) *\) *)
(*   Quickcheck.test gen ~sexp_of ~f:(fun t -> ignore (Block_time.to_time t |> Core_kernel.Time.to_string : string)) *)
(*   (\* Quickcheck.test gen ~sexp_of ~f:(fun t -> *\) *)
(*   (\*     [%test_eq: string] (Block_time.to_string t) (t |> Block_time.to_time |> Core_kernel.Time.to_string)) *\) *)

let%test_unit "block_time_to_int64" =
  ignore
    ( Unsigned.UInt64.to_int64 (Unsigned.UInt64.of_string "3183349418695935435")
      : Int64.t )
