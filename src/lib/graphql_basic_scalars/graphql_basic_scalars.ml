(**
   This file defines basic graphql scalars in a shape usable by graphql_ppx for serialising.

   It is meant to be used by backend graphql code.

   The [grapqh_lib] library re-exports these basic scalars as well as other ones,
   and is meant to be used by client code (via grapqh_ppx).
 *)

module Schema = Graphql_wrapper.Make (Graphql_async.Schema)
open Schema

module type S_JSON = sig
  type t

  val parse : Yojson.Basic.t -> t

  val serialize : t -> Yojson.Basic.t

  val typ : unit -> ('a, t option) Graphql_async.Schema.typ
end

let unsigned_scalar_scalar ~to_string typ_name =
  scalar typ_name
    ~doc:
      (Core.sprintf
         !"String representing a %s number in base 10"
         (Stdlib.String.lowercase_ascii typ_name) )
    ~coerce:(fun num -> `String (to_string num))

module UInt32 : S_JSON with type t = Unsigned.UInt32.t = struct
  type t = Unsigned.UInt32.t

  let parse json = Yojson.Basic.Util.to_string json |> Unsigned.UInt32.of_string

  let serialize value = `String (Unsigned.UInt32.to_string value)

  let typ () =
    unsigned_scalar_scalar ~to_string:Unsigned.UInt32.to_string "UInt32"
end

module UInt64 : S_JSON with type t = Unsigned.UInt64.t = struct
  type t = Unsigned.UInt64.t

  let parse json = Yojson.Basic.Util.to_string json |> Unsigned.UInt64.of_string

  let serialize value = `String (Unsigned.UInt64.to_string value)

  let typ () =
    unsigned_scalar_scalar ~to_string:Unsigned.UInt64.to_string "UInt64"
end

module JSON = struct
  type t = Yojson.Basic.t

  let parse = Base.Fn.id

  let serialize = Base.Fn.id

  let typ () = scalar "JSON" ~doc:"Arbitrary JSON" ~coerce:serialize
end

module STRING : S_JSON with type t = string = struct
  type t = string

  let parse json = Yojson.Basic.Util.to_string json

  let serialize value = `String value

  let typ () = string
end

module Time = struct
  type t = Core_kernel.Time.t

  let parse json =
    Yojson.Basic.Util.to_string json |> Core_kernel.Time.of_string

  let serialize t = `String (Core_kernel.Time.to_string t)

  let typ () = scalar "Time" ~coerce:serialize
end

module Span = struct
  type t = Core.Time.Span.t

  let parse json =
    Yojson.Basic.Util.to_string json
    |> Int64.of_string |> Int64.to_float |> Core.Time.Span.of_ms

  let serialize x =
    `String (Core.Time.Span.to_ms x |> Int64.of_float |> Int64.to_string)

  let typ () = scalar "Span" ~doc:"span" ~coerce:serialize
end

module Make_scalar_using_to_string (T : sig
  type t

  val to_string : t -> string

  val of_string : string -> t
end) (SCALAR : sig
  val name : string

  val doc : string
end) : S_JSON with type t = T.t = struct
  type t = T.t

  let parse json = Yojson.Basic.Util.to_string json |> T.of_string

  let serialize x = `String (T.to_string x)

  let typ () =
    Graphql_async.Schema.scalar SCALAR.name ~doc:SCALAR.doc ~coerce:serialize
end

module Make_scalar_using_base58_check (T : sig
  type t

  val to_base58_check : t -> string

  val of_base58_check_exn : string -> t
end) (SCALAR : sig
  val name : string

  val doc : string
end) : S_JSON with type t = T.t = struct
  type t = T.t

  let parse json = Yojson.Basic.Util.to_string json |> T.of_base58_check_exn

  let serialize x = `String (T.to_base58_check x)

  let typ () =
    Graphql_async.Schema.scalar SCALAR.name ~doc:SCALAR.doc ~coerce:serialize
end


open Base
module Reflection = struct
  let regex = lazy (Re2.create_exn {regex|\_(\w)|regex})

  let underToCamel s =
    Re2.replace_exn (Lazy.force regex) s ~f:(fun m ->
        let s = Re2.Match.get_exn ~sub:(`Index 1) m in
        Base.String.capitalize s )

  (** When Fields.folding, create graphql fields via reflection *)
  let reflect f ~typ acc x =
    let new_name = underToCamel (Field.name x) in
    Graphql_async.Schema.(
      field new_name ~typ ~args:Arg.[] ~resolve:(fun _ v -> f (Field.get x v))
      :: acc)

    let id ~typ a x = reflect Fn.id ~typ a x
end


module Shorthand = struct
  open Reflection

  (* Note: Eta expansion is needed here to combat OCaml's weak polymorphism nonsense *)

  let id ~typ a x = reflect Fn.id ~typ a x

  let nn_int a x = id ~typ:(non_null int) a x

  let nn_int_list a x = id ~typ:(non_null (list (non_null int))) a x

  let int a x = id ~typ:int a x

  let nn_bool a x = id ~typ:(non_null bool) a x

  let bool a x = id ~typ:bool a x

  let nn_string a x = id ~typ:(non_null string) a x

  (* let nn_time a x = *)
  (*   reflect *)
  (*     (fun t -> Block_time.to_time t |> Time.to_string) *)
  (*     ~typ:(non_null string) a x *)

  (* let nn_catchup_status a x = *)
  (*   reflect *)
  (*     (fun o -> *)
  (*       Option.map o *)
  (*         ~f: *)
  (*         (List.map ~f:(function *)
  (*              | ( Transition_frontier.Full_catchup_tree.Node.State.Enum *)
  (*                    .Finished *)
  (*                , _ ) -> *)
  (*                 "finished" *)
  (*              | Failed, _ -> *)
  (*                 "failed" *)
  (*              | To_download, _ -> *)
  (*                 "to_download" *)
  (*              | To_initial_validate, _ -> *)
  (*                 "to_initial_validate" *)
  (*              | To_verify, _ -> *)
  (*                 "to_verify" *)
  (*              | Wait_for_parent, _ -> *)
  (*                 "wait_for_parent" *)
  (*              | To_build_breadcrumb, _ -> *)
  (*                 "to_build_breadcrumb" *)
  (*              | Root, _ -> *)
  (*                 "root" ) ) ) *)
  (*     ~typ:(list (non_null string)) *)
  (*     a x *)

  let string a x = id ~typ:string a x

  (* module F = struct *)
  (*   let int f a x = reflect f ~typ:Schema.int a x *)

  (*   let nn_int f a x = reflect f ~typ:Schema.(non_null int) a x *)

  (*   let string f a x = reflect f ~typ:Schema.string a x *)

  (*   let nn_string f a x = reflect f ~typ:Schema.(non_null string) a x *)
  (* end *)
end
