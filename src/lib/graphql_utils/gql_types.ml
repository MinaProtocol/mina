open Graphql_async.Schema

(** A module providing the typ value used to build the graphql schema as well as
    well as utility functions to build queries and parse responses. *)

module type MAYBE_NULLABLE_TYP = sig
  type 'a final_option_modifier

  type 'a modifier

  type out_before_modifiers

  (** [typ] value for the graphql schema *)
  val typ :
    unit -> (unit, out_before_modifiers modifier final_option_modifier) typ

  type 'a query

  (* type 'a res *)

  val response_of_json :
    'a query -> Yojson.Basic.t -> 'a modifier final_option_modifier

  val mk_query : 'a query -> string
end

module type TYP = sig
  include MAYBE_NULLABLE_TYP

  val typ_nullable : unit -> (unit, out_before_modifiers modifier option) typ
end

(* module Non_null (Aux : sig *)
(*   type new_out *)

(*   type 'a new_res *)
(* end) *)
(* (Input : TYP *)
(*            with type out = Aux.new_out option *)
(*             and type 'a res = 'a Aux.new_res option) : *)
(*   TYP *)
(*     with type out = Aux.new_out *)
(*      and type 'a query = 'a Input.query *)
(*      and type 'a res = 'a Aux.new_res = struct *)
(*   type out = Aux.new_out *)

(*   type 'a res = 'a Aux.new_res *)

(*   type 'a query = 'a Input.query *)

(*   let typ () = non_null @@ Input.typ () *)

(*   let response_of_json query json = *)
(*     match Input.response_of_json query json with *)
(*     | None -> *)
(*         failwith @@ "Non nullable value should not return None " ^ __LOC__ *)
(*     | Some v -> *)
(*         v *)

(*   let mk_query = Input.mk_query *)
(* end *)

module Nullable (Input : TYP with type 'a final_option_modifier = 'a) = struct
  type 'a final_option_modifier = 'a option

  type 'a modifier = 'a Input.modifier

  type out_before_modifiers =
    Input.out_before_modifiers Input.modifier Input.final_option_modifier

  type 'a query = 'a Input.query

  let response_of_json query json =
    Json.nullable Input.response_of_json query json

  let typ = Input.typ_nullable

  let mk_query = Input.mk_query
end

module List (Input : MAYBE_NULLABLE_TYP) = struct
  type 'a final_option_modifier = 'a

  type 'a modifier = 'a Input.modifier Input.final_option_modifier list

  type out_before_modifiers = Input.out_before_modifiers

  type 'a query = 'a Input.query

  type 'a res = 'a Input.modifier Input.final_option_modifier list

  let response_of_json query json =
    Json.non_null_list_of_json Input.response_of_json query json

  let typ_nullable () = list (Input.typ ())

  let typ () = non_null @@ typ_nullable ()

  let mk_query = Input.mk_query
end

(* module ListNullable (Input : TYP) : *)
(*   TYP *)
(*     with type out = Input.out list option *)
(*      and type 'a query = 'a Input.query *)
(*      and type 'a res = 'a Input.res list = struct *)
(*   type 'a res = 'a Input.res list *)

(*   type 'a query = 'a Input.query *)

(*   let response_of_json query json = *)
(*     match json with *)
(*     | `List l -> *)
(*         List.map (Input.response_of_json query) l *)
(*     | _ -> *)
(*         failwith *)
(*         @@ Format.asprintf "expecting a json list (%s): but got\n%a\n " __LOC__ *)
(*              Yojson.Basic.pp json *)

(*   type out = Input.out list option *)

(*   let typ () = list @@ Input.typ () *)

(*   let mk_query = Input.mk_query *)
(* end *)
