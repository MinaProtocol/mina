(* slice_bin_io.ml -- slice up bin_io serialization into pieces from constituent types *)

open Core
open Async

(* open Mina_base *)

let is_yes = function `Yes -> true | _ -> false

let rule_to_yojson rule =
  Yojson.Safe.to_string @@ Ppx_version_runtime.Bin_prot_rule.to_yojson rule

let bin_io_sub ~bin_io ~pos ~len =
  String.sub bin_io ~pos:(pos * 2) ~len:(len * 2)

(* length in hex pairs *)
let bin_io_len ~bin_io = String.length bin_io / 2

let bin_io_hd_exn ~bin_io = bin_io_sub ~bin_io ~pos:0 ~len:1

let bin_io_tl_exn ~bin_io =
  bin_io_sub ~bin_io ~pos:1 ~len:(bin_io_len ~bin_io - 1)

let hex_char_to_int = function
  | '0' ->
      0
  | '1' ->
      1
  | '2' ->
      2
  | '3' ->
      3
  | '4' ->
      4
  | '5' ->
      5
  | '6' ->
      6
  | '7' ->
      7
  | '8' ->
      8
  | '9' ->
      9
  | 'A' ->
      10
  | 'B' ->
      11
  | 'C' ->
      12
  | 'D' ->
      13
  | 'E' ->
      14
  | 'F' ->
      15
  | c ->
      failwithf "Not a hex character: %c" c ()

let make_int_of_hex bits bytes =
  String.foldi bytes ~init:0 ~f:(fun ndx sum c ->
      sum + (hex_char_to_int c lsl (bits - ((ndx + 1) * 4))) )

let int_of_hex8 = make_int_of_hex 8

let int_of_hex16 = make_int_of_hex 16

let int_of_hex32 = make_int_of_hex 32

let int_of_hex64 = make_int_of_hex 64

let code_neg_int8 = "FF"

let code_int16 = "FE"

let code_int32 = "FD"

let code_int64 = "FC"

let get_nat0_value ~bin_io =
  match bin_io_sub ~bin_io ~pos:0 ~len:1 with
  | s when String.equal s code_int16 ->
      int_of_hex16 (bin_io_sub ~bin_io ~pos:1 ~len:2)
  | s when String.equal s code_int32 ->
      int_of_hex32 (bin_io_sub ~bin_io ~pos:1 ~len:4)
  | s when String.equal s code_int64 ->
      int_of_hex64 (bin_io_sub ~bin_io ~pos:1 ~len:8)
  | byte ->
      int_of_hex8 byte

let find_polyvar_args ~tag_hash args =
  match
    List.find args ~f:(fun arg ->
        match arg with
        | Ppx_version_runtime.Bin_prot_rule.Tagged {hash; _} ->
            tag_hash = hash
        | Inherited _ref ->
            (* TODO: the ref will be an identifier
           create a table of polyvar types with their lengths ? *)
            failwith "Inherited polymorphic variant, don't know its length" )
  with
  | None ->
      failwith "Couldn't find polymorphic variant with matching hash"
  | Some (Tagged {polyvar_args; _}) ->
      polyvar_args
  | Some (Inherited _) ->
      failwith "Inherited polymorphic variant, should be unreachable"

let get_nat0_expected_len ~bin_io =
  match bin_io_hd_exn ~bin_io with
  | s when String.equal s code_int16 ->
      3
  | s when String.equal s code_int32 ->
      5
  | s when String.equal s code_int64 ->
      9
  | _ ->
      1

let get_nat0_consequents ~bin_io =
  let nat0_len = get_nat0_expected_len ~bin_io in
  let nat0_bin_io = bin_io_sub ~bin_io ~pos:0 ~len:nat0_len in
  let nat0_value = get_nat0_value ~bin_io:nat0_bin_io in
  let bin_io =
    bin_io_sub ~bin_io ~pos:nat0_len ~len:(bin_io_len ~bin_io - nat0_len)
  in
  (nat0_len, nat0_value, bin_io)

let get_summand_tag_len_bin_io
    ~(summands : Ppx_version_runtime.Bin_prot_rule.summand list) ~bin_io =
  let num_tags = List.length summands in
  let tag_len = if num_tags <= 256 then 1 else 2 in
  (* which summand? *)
  let tag_value =
    if tag_len = 1 then int_of_hex8 (bin_io_sub ~bin_io ~pos:0 ~len:tag_len)
    else int_of_hex16 (bin_io_sub ~bin_io ~pos:0 ~len:tag_len)
  in
  let bin_io =
    bin_io_sub ~bin_io ~pos:tag_len ~len:(bin_io_len ~bin_io - tag_len)
  in
  let summand = List.nth_exn summands tag_value in
  assert (summand.index = tag_value) ;
  (summand, tag_len, bin_io)

let rec expected_len ~bin_io ~(rule : Ppx_version_runtime.Bin_prot_rule.t) =
  match rule with
  | Nat0 ->
      get_nat0_expected_len ~bin_io
  | Unit ->
      1
  | Bool ->
      1
  | String ->
      let nat0_len, nat0_value, _bin_io = get_nat0_consequents ~bin_io in
      nat0_len + nat0_value
  | Char ->
      1
  (* integers *)
  | Int | Int32 | Int64 | Native_int -> (
    match bin_io_hd_exn ~bin_io with
    | s when String.equal s code_neg_int8 ->
        2
    | s when String.equal s code_int16 ->
        3
    | s when String.equal s code_int32 ->
        5
    | s when String.equal s code_int64 ->
        9
    | _ ->
        1 )
  (* end integers *)
  | Float ->
      8
  | Option rule' ->
      1 + expected_len ~bin_io:(bin_io_tl_exn ~bin_io) ~rule:rule'
  | Record fields ->
      List.fold_left fields ~init:0
        ~f:(fun sum
           ({field_rule; _} : Ppx_version_runtime.Bin_prot_rule.record_field)
           ->
          let bin_io =
            bin_io_sub ~bin_io ~pos:sum ~len:(bin_io_len ~bin_io - sum)
          in
          sum + expected_len ~bin_io ~rule:field_rule )
  | Tuple items ->
      List.fold_left items ~init:0 ~f:(fun sum rule ->
          let bin_io =
            bin_io_sub ~bin_io ~pos:sum ~len:(bin_io_len ~bin_io - sum)
          in
          expected_len ~bin_io ~rule )
  | Sum summands ->
      let ( (summand : Ppx_version_runtime.Bin_prot_rule.summand)
          , tag_len
          , bin_io ) =
        get_summand_tag_len_bin_io ~bin_io ~summands
      in
      let args_len =
        List.fold_left summand.ctor_args ~init:0 ~f:(fun sum rule ->
            let bin_io =
              bin_io_sub ~bin_io ~pos:sum ~len:(bin_io_len ~bin_io - sum)
            in
            sum + expected_len ~bin_io ~rule )
      in
      tag_len + args_len
  | Polyvar args ->
      let tag_len = 4 in
      let tag_hash = int_of_hex32 (bin_io_sub ~bin_io ~pos:0 ~len:tag_len) in
      let bin_io =
        bin_io_sub ~bin_io ~pos:tag_len ~len:(bin_io_len ~bin_io - tag_len)
      in
      let polyvar_args = find_polyvar_args ~tag_hash args in
      let args_len =
        List.fold_left polyvar_args ~init:0 ~f:(fun sum rule ->
            let bin_io =
              bin_io_sub ~bin_io ~pos:sum ~len:(bin_io_len ~bin_io - sum)
            in
            sum + expected_len ~bin_io ~rule )
      in
      tag_len + args_len
  | List rule ->
      let nat0_len, nat0_value, bin_io = get_nat0_consequents ~bin_io in
      let item_len = expected_len ~bin_io ~rule in
      nat0_len + (item_len * nat0_value)
  | Hashtable {key_rule; value_rule} ->
      let nat0_len, nat0_value, bin_io = get_nat0_consequents ~bin_io in
      (* we have to iterate over the bin_io, because the keys and values may
       have variable-length encodings
    *)
      let rec go ~bin_io sum n =
        if n <= 0 then sum
        else
          let key_len = expected_len ~bin_io ~rule:key_rule in
          let bin_io =
            bin_io_sub ~bin_io ~pos:key_len ~len:(bin_io_len ~bin_io - key_len)
          in
          let value_len = expected_len ~bin_io ~rule:value_rule in
          let bin_io =
            bin_io_sub ~bin_io ~pos:value_len
              ~len:(bin_io_len ~bin_io - value_len)
          in
          go ~bin_io (sum + key_len + value_len) (n - 1)
      in
      nat0_len + go ~bin_io 0 nat0_value
  | Vec ->
      let nat0_len, nat0_value, _bin_io = get_nat0_consequents ~bin_io in
      (* TODO: doubles are 8 bytes? *)
      nat0_len + (nat0_value * 8)
  | Bigstring ->
      let nat0_len, nat0_value, _bin_io = get_nat0_consequents ~bin_io in
      (* characters are 1 byte *)
      nat0_len + nat0_value
  | Reference (Resolved {ref_rule; _}) ->
      expected_len ~bin_io ~rule:ref_rule
  | Reference (Unresolved _) ->
      failwithf "Can't take length of unresolved reference in rule: %s"
        (rule_to_yojson rule) ()
  | Type_var _
  | Self_reference _
  | Type_abstraction (_, _)
  | Type_closure (_, _) ->
      failwithf "Rule should not appear for serialized data: %s"
        (rule_to_yojson rule) ()

let rec slice_from_rule ~directory ~bin_io
    ~(rule : Ppx_version_runtime.Bin_prot_rule.t) =
  assert (String.length bin_io = expected_len ~bin_io ~rule) ;
  Out_channel.with_file (directory ^/ "data.hex") ~f:(fun out_ch ->
      Out_channel.output_string out_ch bin_io ) ;
  match rule with
  (* rules with no contained rules *)
  | Nat0
  | Unit
  | Bool
  | String
  | Char
  | Int
  | Int32
  | Int64
  | Native_int
  | Float ->
      return ()
  (* end rules with no contained rules *)
  | Option rule' -> (
    match bin_io_sub ~bin_io ~pos:0 ~len:1 with
    | "00" ->
        return ()
    | "01" ->
        let bin_io = bin_io_sub ~bin_io ~pos:1 ~len:(bin_io_len ~bin_io - 1) in
        slice_from_rule ~directory ~bin_io ~rule:rule'
    | s ->
        failwithf "Unexpected leading hex pair for Option: %s" s () )
  | Record fields ->
      let%bind _total =
        Deferred.List.fold fields ~init:0
          ~f:(fun sum {field_rule; field_name; _} ->
            let bin_io0 =
              bin_io_sub ~bin_io ~pos:sum ~len:(bin_io_len ~bin_io - sum)
            in
            let len = expected_len ~bin_io:bin_io0 ~rule:field_rule in
            let bin_io = bin_io_sub ~bin_io:bin_io0 ~pos:0 ~len in
            let%map () =
              slice_from_rule ~directory:(directory ^/ field_name) ~bin_io
                ~rule:field_rule
            in
            sum + len )
      in
      return ()
  | Tuple rules ->
      let%bind _total =
        Deferred.List.foldi rules ~init:0 ~f:(fun ndx sum rule ->
            let bin_io0 =
              bin_io_sub ~bin_io ~pos:sum ~len:(bin_io_len ~bin_io - sum)
            in
            let len = expected_len ~bin_io:bin_io0 ~rule in
            let bin_io = bin_io_sub ~bin_io:bin_io0 ~pos:0 ~len in
            let%map () =
              slice_from_rule
                ~directory:(directory ^/ Int.to_string ndx)
                ~bin_io ~rule
            in
            sum + len )
      in
      return ()
  | Sum summands ->
      let ( (summand : Ppx_version_runtime.Bin_prot_rule.summand)
          , tag_len
          , bin_io ) =
        get_summand_tag_len_bin_io ~bin_io ~summands
      in
      let bin_io =
        bin_io_sub ~bin_io ~pos:tag_len ~len:(bin_io_len ~bin_io - tag_len)
      in
      let directory = directory ^/ summand.ctor_name in
      let%bind () = Unix.mkdir directory in
      let%bind _total =
        Deferred.List.foldi summand.ctor_args ~init:0 ~f:(fun ndx sum rule ->
            let bin_io0 =
              bin_io_sub ~bin_io ~pos:sum ~len:(bin_io_len ~bin_io - sum)
            in
            let len = expected_len ~bin_io:bin_io0 ~rule in
            let bin_io = bin_io_sub ~bin_io:bin_io0 ~pos:0 ~len in
            let%map () =
              slice_from_rule
                ~directory:(directory ^/ Int.to_string ndx)
                ~bin_io ~rule
            in
            sum + len )
      in
      return ()
  | Polyvar _ | List _ | Hashtable _ | Vec | Bigstring ->
      return ()
  | Reference (Resolved {ref_rule; _}) ->
      slice_from_rule ~directory ~bin_io ~rule:ref_rule
  | Reference (Unresolved _) ->
      failwithf "Unresolved reference in rule: %s" (rule_to_yojson rule) ()
  | Self_reference _ ->
      return ()
  | Type_var _ | Type_abstraction (_, _) | Type_closure (_, _) ->
      failwithf "Rule should not appear for serialized data: %s"
        (rule_to_yojson rule) ()

let slice_from_layout ~directory ~bin_io
    ~(layout : Ppx_version_runtime.Bin_prot_layout.t) =
  let rule = layout.bin_prot_rule in
  slice_from_rule ~directory ~bin_io ~rule

let main ~layout_file ~bin_io_file ~output_directory () =
  let logger = Logger.create () in
  let layout_json = Yojson.Safe.from_file layout_file in
  let layout =
    match Ppx_version_runtime.Bin_prot_layout.of_yojson layout_json with
    | Ok layout ->
        layout
    | Error err ->
        [%log fatal] "Could not parse layout JSON"
          ~metadata:[("error", `String err)] ;
        Core_kernel.exit 1
  in
  [%log info] "Successfully read layout from layout file \"%s\"" layout_file ;
  let bin_io_hex_string =
    In_channel.with_file bin_io_file ~f:(fun in_channel ->
        In_channel.input_all in_channel )
  in
  [%log info] "Successfully read bin_io serialization from file \"%s\""
    bin_io_file ;
  let%bind outdir_exists = Sys.file_exists output_directory in
  let%bind () =
    if not (is_yes outdir_exists) then (
      [%log info] "Output directory \"%s\" does not exist, creating it"
        output_directory ;
      Unix.mkdir output_directory )
    else
      let%bind outdir_isdir = Sys.is_directory output_directory in
      if not (is_yes outdir_isdir) then (
        [%log fatal] "File \"%s\" exists, but is not a directory"
          output_directory ;
        Core_kernel.exit 1 )
      else (* directory exists *)
        return ()
  in
  slice_from_layout ~directory:output_directory ~bin_io:bin_io_hex_string
    ~layout

let () =
  Command.(
    run
      (let open Let_syntax in
      Command.async ~summary:"Slice bin_io serialization into pieces"
        (let%map layout_file =
           Param.flag "--layout-file"
             ~doc:"file File containing a layout for a bin_io-serialized type"
             Param.(required string)
         and bin_io_file =
           Param.flag "--bin-io-file"
             ~doc:"file File containing a bin_io-serialization in hexadecimal"
             Param.(required string)
         and output_directory =
           Param.flag "--output-directory"
             ~doc:
               "directory directory where the pieces of the serialization \
                will be written"
             Param.(required string)
         in
         main ~layout_file ~bin_io_file ~output_directory)))
