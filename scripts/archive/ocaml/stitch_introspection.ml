open Core
open Json_stitch

let is_input_association_list ~type_name json =
  let open Combinators in
  let open Option.Let_syntax in
  let open Pattern in
    compute_validity
      ( assoc_list json
      >>= ( key_and_value ~key:"name"
              ~value:(String type_name)
          && key_and_value ~key:"enumValues" ~value:Null ) )

let change_input_fields_list ~f json =
  let open Combinators in
  let open Change in
  association_list json
      ~f:
        (value_with_name "inputFields"
           ~f:
             (list  ~f:(fun json_list -> 
              Result.return (f json_list)
             
             )))

let remove_user_commands_input_commands =
  let open Combinators in
  let predicate = 
    is_input_association_list ~type_name:"user_commands_insert_input"
  in
  let action json =
    change_input_fields_list json ~f:(fun json_list -> 
    List.filter json_list ~f:(fun json_elem ->
            let open Option.Let_syntax in
            let open Pattern in
            not
            @@ compute_validity
                ( assoc_list json_elem >>= assoc_list_elem "name"
                >>= ( is_equal_scalar (String "receiver")
                    || is_equal_scalar (String "sender") ) ) ))   
  in
  stitch ~predicate ~action

let remove_blocks_input_commands = 
  let open Combinators in
  let predicate = 
    is_input_association_list ~type_name:"blocks_user_commands_insert_input"
  in
  let action json =
    change_input_fields_list json ~f:(fun json_list -> 
    List.filter json_list ~f:(fun json_elem ->
            let open Option.Let_syntax in
            let open Pattern in
            not
            @@ compute_validity
                ( assoc_list json_elem >>= assoc_list_elem "name"
                >>= ( is_equal_scalar (String "block_id") || is_equal_scalar (String "receipt_chain_hash_id") 
                  || is_equal_scalar (String "user_command_id") ) ) ))
  in
  stitch ~predicate ~action

let remove_receipt_chain_input =
  let open Combinators in
  let predicate =
    is_input_association_list ~type_name:"receipt_chain_hashes_insert_input"
  in
  let action json =
    change_input_fields_list json ~f:(fun json_list -> 
    List.filter json_list ~f:(fun json_elem ->
            let open Option.Let_syntax in
            let open Pattern in
            not
            @@ compute_validity
                ( assoc_list json_elem >>= assoc_list_elem "name"
                >>= ( is_equal_scalar (String "parent_id")   ) ) ))
  in
  stitch ~predicate ~action
  
let change_constraint = 
  let open Combinators in
  let predicate json =
    let open Option.Let_syntax in
    let open Pattern in
        compute_validity
      ( assoc_list json >>= ( key_and_value ~key:"name"
              ~value:(String "constraint") ))
    in
  let action json =
    let open Change in
    association_list json ~f:(value_with_name "name" ~f: (Fn.const (Or_error.return @@ `String "constraint_")))
  in
    stitch ~predicate ~action

let read_json json_string =
  let json = Yojson.Basic.from_string json_string in
  let cleaned_user_commands = remove_user_commands_input_commands json in
  Core.print_string @@ Yojson.Basic.prettify
  @@ Yojson.Basic.to_string cleaned_user_commands

let read_from_standard_input () =
  (* There is only one async call in this entire program so it's okay to make this synchronous call *)
  let json_string = Core.In_channel.input_all Core.In_channel.stdin in  
  let json = Yojson.Basic.from_string json_string
    |> remove_user_commands_input_commands 
    |> change_constraint 
    |> remove_blocks_input_commands
    |> remove_receipt_chain_input  in
    Core.print_string @@ Yojson.Basic.prettify @@ Yojson.Basic.to_string json ;
    ()

let () = read_from_standard_input ()
