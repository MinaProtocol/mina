[%%import "/src/config.mlh"]

open Core_kernel

let field_of_bool =
  Snark_params.Tick.(fun b -> if b then Field.one else Field.zero)

let bit_length_to_triple_length n =
  let r = n mod 3 in
  let k = n / 3 in
  if r = 0 then k else k + 1

let split_last_exn =
  let rec go acc x xs =
    match xs with [] -> (List.rev acc, x) | x' :: xs -> go (x :: acc) x' xs
  in
  function [] -> failwith "split_last: Empty list" | x :: xs -> go [] x xs

let two_to_the i = Bignum_bigint.(pow (of_int 2) (of_int i))

(* TODO: This shouldn't live here.. *)
let exists_deferred ?request:req ?compute typ =
  let open Snark_params.Tick.Run in
  let open Async_kernel in
  (* Set up a full Ivar, in case we are generating the constraint system. *)
  let deferred = ref (Ivar.create_full ()) in
  (* Request or compute the [Deferred.t] value. *)
  let requested = exists ?request:req ?compute (Typ.Internal.ref ()) in
  as_prover (fun () ->
      (* If we are generating the witness, create a new Ivar.. *)
      deferred := Ivar.create () ;
      (* ..and fill it when the value we want to read resolves. *)
      Deferred.upon (As_prover.Ref.get requested) (fun _ ->
          Ivar.fill !deferred () ) ) ;
  (* Await the [Deferred.t] if we're generating the witness, otherwise we
     immediately bind over the filled Ivar and continue.
  *)
  Deferred.map (Ivar.read !deferred) ~f:(fun () ->
      (* Retrieve the value by peeking in the known-resolved deferred. *)
      exists typ ~compute:(fun () ->
          Option.value_exn @@ Deferred.peek @@ As_prover.Ref.get requested ) )
