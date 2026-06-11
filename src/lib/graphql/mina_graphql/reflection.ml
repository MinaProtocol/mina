open Core
open Graphql_async

let regex = lazy (Re2.create_exn {regex|\_(\w)|regex})

let underToCamel s =
  Re2.replace_exn (Lazy.force regex) s ~f:(fun m ->
      let s = Re2.Match.get_exn ~sub:(`Index 1) m in
      String.capitalize s )

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
      (fun t -> Block_time.to_time_exn t)
      ~typ:(non_null (Graphql_lib.Scalars.Time.typ ()))
      a x

  let nn_catchup_status a x =
    let module Enum = Transition_frontier.Full_catchup_tree.Node.State.Enum in
    (* The catchup status carries a count per job state. Expose those counts as
       a structured object so callers can read how many blocks sit in each stage
       of the pipeline, rather than just the list of stage names. *)
    let count_field name enum =
      field name ~typ:(non_null Schema.int)
        ~args:Arg.[]
        ~resolve:(fun _ states ->
          Option.value ~default:0
            (List.Assoc.find states enum ~equal:Enum.equal) )
    in
    reflect Fn.id
      ~typ:
        (obj "CatchupStatus"
           ~doc:"Number of blocks in the ledger-catchup pipeline, by job state"
           ~fields:(fun _ ->
             [ count_field "finished" Enum.Finished
             ; count_field "failed" Enum.Failed
             ; count_field "toDownload" Enum.To_download
             ; count_field "toInitialValidate" Enum.To_initial_validate
             ; count_field "toVerify" Enum.To_verify
             ; count_field "waitForParent" Enum.Wait_for_parent
             ; count_field "toBuildBreadcrumb" Enum.To_build_breadcrumb
             ; count_field "root" Enum.Root
             ] ) )
      a x

  let string a x = id ~typ:string a x

  module F = struct
    let int f a x = reflect f ~typ:Schema.int a x

    let nn_int f a x = reflect f ~typ:Schema.(non_null int) a x

    let string f a x = reflect f ~typ:Schema.string a x

    let nn_string f a x = reflect f ~typ:Schema.(non_null string) a x
  end
end
