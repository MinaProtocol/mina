open Core
open Async

module Stable = struct
  module V1 = struct
    module T = struct
      type 'a t = [`One of 'a | `Two of 'a * 'a]
      [@@deriving bin_io, equal, compare, hash, sexp, version, yojson]
    end

    include T
  end

  module Latest = V1
end

type 'a t = 'a Stable.V1.t [@@deriving compare, equal, hash, sexp, yojson]

let length = function `One _ -> 1 | `Two _ -> 2

let to_list = function `One a -> [a] | `Two (a, b) -> [a; b]

let group_sequence : 'a Sequence.t -> 'a t Sequence.t =
 fun to_group ->
  Sequence.unfold ~init:to_group ~f:(fun acc ->
      match Sequence.next acc with
      | None ->
          None
      | Some (a, rest_1) -> (
        match Sequence.next rest_1 with
        | None ->
            Some (`One a, Sequence.empty)
        | Some (b, rest_2) ->
            Some (`Two (a, b), rest_2) ) )

let group_list : 'a list -> 'a t list =
 fun xs -> xs |> Sequence.of_list |> group_sequence |> Sequence.to_list

let zip : 'a t -> 'b t -> ('a * 'b) t Or_error.t =
 fun a b ->
  match (a, b) with
  | `One a1, `One b1 ->
      Ok (`One (a1, b1))
  | `Two (a1, a2), `Two (b1, b2) ->
      Ok (`Two ((a1, b1), (a2, b2)))
  | _ ->
      Or_error.error_string "One_or_two.zip mismatched"

let zip_exn : 'a t -> 'b t -> ('a * 'b) t =
 fun a b -> Or_error.ok_exn @@ zip a b

module Monadic2 (M : Monad.S2) :
  Intfs.Monadic2 with type ('a, 'e) m := ('a, 'e) M.t = struct
  let sequence : ('a, 'e) M.t t -> ('a t, 'e) M.t = function
    | `One def ->
        M.map def ~f:(fun x -> `One x)
    | `Two (def1, def2) ->
        let open M.Let_syntax in
        let%bind a = def1 in
        let%map b = def2 in
        `Two (a, b)

  let map : 'a t -> f:('a -> ('b, 'e) M.t) -> ('b t, 'e) M.t =
   fun t ~f ->
    (* We could use sequence here, but this approach saves us computation in the
       Result and option monads when the first component of a `Two fails. *)
    match t with
    | `One a ->
        M.map ~f:(fun x -> `One x) (f a)
    | `Two (a, b) ->
        let open M.Let_syntax in
        let%bind a' = f a in
        let%map b' = f b in
        `Two (a', b')

  let fold :
         'a t
      -> init:'accum
      -> f:('accum -> 'a -> ('accum, 'e) M.t)
      -> ('accum, 'e) M.t =
   fun t ~init ~f ->
    match t with
    | `One a ->
        f init a
    | `Two (a, b) ->
        M.bind (f init a) ~f:(fun x -> f x b)
end

module Monadic (M : Monad.S) : Intfs.Monadic with type 'a m := 'a M.t =
  Monadic2 (Base__.Monad_intf.S_to_S2 (M))

module Deferred_result = Monadic2 (Deferred.Result)
module Ident = Monadic (Monad.Ident)
module Deferred = Monadic (Deferred)
module Option = Monadic (Option)
module Or_error = Monadic (Or_error)

let map = Ident.map

let fold = Ident.fold

let iter t ~f = match t with `One a -> f a | `Two (a, b) -> f a ; f b

let fold_until ~init ~f ~finish t =
  Container.fold_until ~fold ~init ~f ~finish t

let gen inner_gen =
  Quickcheck.Generator.(
    union
      [ map inner_gen ~f:(fun x -> `One x)
      ; map (tuple2 inner_gen inner_gen) ~f:(fun pair -> `Two pair) ])
