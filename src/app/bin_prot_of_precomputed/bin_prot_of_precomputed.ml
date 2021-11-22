(* bin_prot_of_precomputed -- convert precomputed blocks to (hexed) Bin_prot format *)

open Core_kernel
open Async
open Mina_transition

let main ~files () =
  let logger = Logger.create () in
  [%log info] "Converting precomputed blocks to hexed Bin_prot format" ;
  Deferred.List.iter files ~f:(fun file ->
      [%log info] "Processing file %s" file ;
      let hex_file =
        match String.split file ~on:'.' with
        | [prefix; json] when String.equal (String.lowercase json) "json" ->
            sprintf "%s.hex" prefix
        | _ ->
            [%log error] "Expected filename with 'json' suffix" ;
            Core.exit 1
      in
      let json =
        In_channel.with_file file ~f:(fun in_channel ->
            try Yojson.Safe.from_channel in_channel with
            | Yojson.Json_error err ->
                [%log error] "Could not parse JSON from file"
                  ~metadata:[("file", `String file); ("error", `String err)] ;
                Core.exit 1
            | exn ->
                (* should be unreachable *)
                [%log error] "Internal error when processing file"
                  ~metadata:
                    [ ("file", `String file)
                    ; ("error", `String (Exn.to_string exn)) ] ;
                Core.exit 1 )
      in
      let precomputed =
        match External_transition.Precomputed_block.of_yojson json with
        | Ok precomputed ->
            precomputed
        | Error err ->
            [%log error] "Could not parse JSON into precomputed block: %s" err ;
            Core.exit 1
      in
      let external_transition =
        External_transition.precomputed_block_to_external_transition
          precomputed
      in
      let block_bytes =
        let len =
          External_transition.Stable.Latest.bin_size_t external_transition
        in
        let buf = Bin_prot.Common.create_buf len in
        ignore
          ( External_transition.Stable.Latest.bin_write_t buf ~pos:0
              external_transition
            : int ) ;
        let bytes = Bytes.create len in
        Bin_prot.Common.blit_buf_bytes buf bytes ~len ;
        bytes
      in
      [%log info]
        "Writing Bin_prot serialization of precomputed block to file %s"
        hex_file ;
      Out_channel.with_file hex_file ~f:(fun out_ch ->
          let block_hex = Hex.Safe.to_hex (Bytes.to_string block_bytes) in
          Out_channel.output_string out_ch block_hex ) ;
      return () )

let () =
  Command.(
    run
      (let open Let_syntax in
      Command.async
        ~summary:"Convert precomputed blocks to hexed Bin_prot format"
        (let%map files =
           Param.anon Anons.(sequence ("FILES" %: Param.string))
         in
         main ~files)))
