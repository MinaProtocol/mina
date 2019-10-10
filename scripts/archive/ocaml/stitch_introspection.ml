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

let remove_key_from_input ~type_name fields = 
  let open Combinators in
  let predicate = 
    is_input_association_list ~type_name
  in
  let action json =
    change_input_fields_list json ~f:(fun json_list -> 
    List.filter json_list ~f:(fun json_elem ->
            let open Option.Let_syntax in
            let open Pattern in
            not
            @@ compute_validity
                ( assoc_list json_elem >>= assoc_list_elem "name"
                >>= ( 
                  fun json -> 
                    Some (List.exists ~f:(fun field_name -> Scalar.is_json_equal (String field_name) json ) fields )
                   ) ) ))
  in
  stitch ~predicate ~action

let remove_user_commands_input_commands =
  remove_key_from_input ~type_name:"user_commands_insert_input"
    ["name"; "receiver"; "sender"; "id"]

let remove_receipt_chain_input =
  remove_key_from_input ~type_name:"receipt_chain_hashes_insert_input" ["id"; "parent_id"]

let remove_state_hashes_input =
  remove_key_from_input ~type_name:"state_hashes_insert_input" ["id"]

let remove_fee_transfers_input =
  remove_key_from_input ~type_name:"fee_transfers_insert_input" ["id"]

let remove_blocks_input =
  remove_key_from_input ~type_name:"blocks_insert_input" ["creator"; "parent_hash"; "state_hash"]

let remove_public_keys_input =
  remove_key_from_input ~type_name:"public_keys_insert_input" ["id"]

let remove_snark_job_input =
  remove_key_from_input ~type_name:"snark_jobs_insert_input" ["id"]

let remove_blocks_user_commands_input = 
  remove_key_from_input ~type_name:"blocks_user_commands_insert_input" ["block_id"; "receipt_chain_hash_id"; "user_command_id"]

let remove_blocks_fee_transfers_input = 
  remove_key_from_input ~type_name:"blocks_fee_transfers_insert_input" ["block_id"; "fee_transfer_id"]
  
let remove_blocks_snark_jobs_input = 
  remove_key_from_input ~type_name:"blocks_snark_jobs_insert_input" ["block_id"; "snark_job_id"]

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
    |> change_constraint 
    |> remove_public_keys_input
    |> remove_user_commands_input_commands 
    |> remove_receipt_chain_input
    |> remove_state_hashes_input
    |> remove_blocks_input
    |> remove_snark_job_input
    |> remove_fee_transfers_input  
    |> remove_blocks_user_commands_input
    |> remove_blocks_fee_transfers_input
    |> remove_blocks_snark_jobs_input
    in
    Core.print_string @@ Yojson.Basic.prettify @@ Yojson.Basic.to_string json ;
    ()

let () = read_from_standard_input ()
