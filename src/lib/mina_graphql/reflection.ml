open Core
open Graphql_async
module Ledger = Mina_ledger.Ledger

let regex = lazy (Re2.create_exn {regex|\_(\w)|regex})

let underToCamel s =
  Re2.replace_exn (Lazy.force regex) s ~f:(fun m ->
      let s = Re2.Match.get_exn ~sub:(`Index 1) m in
      String.capitalize s)

(** When Fields.folding, create graphql fields via reflection *)
let reflect f ~typ acc x =
  let new_name = underToCamel (Field.name x) in
  Schema.(
    field new_name ~typ ~args:Arg.[] ~resolve:(fun _ v -> f (Field.get x v))
    :: acc)

module Shorthand = struct
  open Schema

  (* Note: Eta expansion is needed here to combat OCaml's weak polymorphism nonsense *)

  let id ~typ a x = reflect Fn.id ~typ a x

  let nn_int a x = id ~typ:(non_null int) a x

  let nn_int_list a x = id ~typ:(non_null (list (non_null int))) a x

  let int a x = id ~typ:int a x

  let nn_bool a x = id ~typ:(non_null bool) a x

  let bool a x = id ~typ:bool a x

  let nn_string a x = id ~typ:(non_null string) a x

  let nn_time a x =
    reflect
      (fun t -> Block_time.to_time t |> Time.to_string)
      ~typ:(non_null string) a x

  let nn_catchup_status a x =
    reflect
      (fun o ->
        Option.map o
          ~f:
            (List.map ~f:(function
              | ( Transition_frontier.Full_catchup_tree.Node.State.Enum.Finished
                , _ ) ->
                  "finished"
              | Failed, _ ->
                  "failed"
              | To_download, _ ->
                  "to_download"
              | To_initial_validate, _ ->
                  "to_initial_validate"
              | To_verify, _ ->
                  "to_verify"
              | Wait_for_parent, _ ->
                  "wait_for_parent"
              | To_build_breadcrumb, _ ->
                  "to_build_breadcrumb"
              | Root, _ ->
                  "root")))
      ~typ:(list (non_null string))
      a x

  let string a x = id ~typ:string a x

  module F = struct
    let int f a x = reflect f ~typ:Schema.int a x

    let nn_int f a x = reflect f ~typ:Schema.(non_null int) a x

    let string f a x = reflect f ~typ:Schema.string a x

    let nn_string f a x = reflect f ~typ:Schema.(non_null string) a x
  end
end
