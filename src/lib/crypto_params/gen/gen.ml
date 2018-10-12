open Ppxlib
open Asttypes
open Parsetree
open Longident
open Core
open Async

module Gen_params (M : sig
  val random_bool : unit -> bool
end) =
struct
  open M
  module Impl = Snarky.Snark0.Make (Snarky.Libsnark.Mnt4.GM)
  module Group = Snarky.Libsnark.Mnt6.Group
  open Tuple_lib

  let bigint_of_bits bits =
    List.foldi bits ~init:Bigint.zero ~f:(fun i acc b ->
        if b then Bigint.(acc + (of_int 2 lsl i)) else acc )

  let rec random_field_element () =
    let n =
      bigint_of_bits
        (List.init Impl.Field.size_in_bits ~f:(fun _ -> random_bool ()))
    in
    if Bigint.(n < Impl.Field.size) then
      Impl.Bigint.(to_field (of_bignum_bigint n))
    else random_field_element ()

  let sqrt x =
    let a = Impl.Field.sqrt x in
    let b = Impl.Field.negate a in
    if Impl.Bigint.(compare (of_field a) (of_field b)) = -1 then (a, b)
    else (b, a)

  (* y^2 = x^3 + a * x + b *)
  let rec random_point () =
    let x = random_field_element () in
    let y2 =
      let open Impl.Field in
      let open Infix in
      (x * square x)
      + (Snarky.Libsnark.Curves.Mnt6.G1.Coefficients.a * x)
      + Snarky.Libsnark.Curves.Mnt6.G1.Coefficients.b
    in
    if Impl.Field.is_square y2 then
      let a, b = sqrt y2 in
      if random_bool () then (x, a) else (x, b)
    else random_point ()

  let max_input_size = 8000

  let params =
    List.init (max_input_size / 4) ~f:(fun i ->
        let t = Group.of_coords (random_point ()) in
        let tt = Group.double t in
        (t, tt, Group.add t tt, Group.double tt) )

  let expr ~loc =
    let module E = Ppxlib.Ast_builder.Make (struct
      let loc = loc
    end) in
    let open E in
    let earray =
      E.pexp_array
        (List.map params ~f:(fun (g1, g2, g3, g4) ->
             E.pexp_tuple
               (List.map [g1; g2; g3; g4] ~f:(fun g ->
                    let x, y = Group.to_coords g in
                    E.pexp_tuple
                      [ estring (Impl.Field.to_string x)
                      ; estring (Impl.Field.to_string y) ] )) ))
    in
    let%expr conv (x, y) =
      Inner_curve.of_coords (Tick0.Field.of_string x, Tick0.Field.of_string y)
    in
    Array.map
      (fun (g1, g2, g3, g4) -> (conv g1, conv g2, conv g3, conv g4))
      [%e earray]
end

type state = {digest: string; i: int; j: int}

let digest_length_in_bits = 256

let seed = "CodaPedersenParams"

let ith_bit s i = (Char.to_int s.[i / 8] lsr (i mod 8)) land 1 = 1

let update ({digest; i; j} as state) =
  if j = digest_length_in_bits then
    let digest =
      (Digestif.SHA256.digest_string (seed ^ Int.to_string i) :> string)
    in
    let b = ith_bit digest 0 in
    (b, {digest; i= i + 1; j= 1})
  else
    let b = ith_bit digest j in
    (b, {state with j= j + 1})

let init = {digest= (Digestif.SHA256.digest_string seed :> string); i= 0; j= 0}

let params ~loc =
  let random_bool =
    let s = ref init in
    fun () ->
      let b, s' = update !s in
      s := s' ;
      b
  in
  let module P = Gen_params (struct
    let random_bool = random_bool
  end) in
  P.expr ~loc

let structure ~loc =
  let module E = Ppxlib.Ast_builder.Make (struct
    let loc = loc
  end) in
  let open E in
  [%str open Init

        let params = [%e params ~loc]]

let main () =
  let fmt =
    Format.formatter_of_out_channel (Out_channel.create "pedersen_params.ml")
  in
  Pprintast.top_phrase fmt (Ptop_def (structure ~loc:Ppxlib.Location.none)) ;
  exit 0

let () =
  ignore (main ()) ;
  never_returns (Scheduler.go ())
