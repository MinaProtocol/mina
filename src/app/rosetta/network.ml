open Models

let router route body =
  let open Respond.Parse_arg in
  match route with
  | ["list"] ->
      let%map _meta = Metadata_request.of_yojson body in
      Respond.json
        (Network_list_response.to_yojson
           { Network_list_response.network_identifiers=
               [ { Network_identifier.blockchain= "coda"
                 ; network= "testnet"
                 ; sub_network_identifier= None } ] })
  | ["status"] ->
      let%map _network = Network_request.of_yojson body in
      Respond.json
        (Network_status_response.to_yojson
           { Network_status_response.current_block_identifier=
               Block_identifier.create Int64.one "???"
           ; current_block_timestamp= Int64.one
           ; genesis_block_identifier= Block_identifier.create Int64.one "???"
           ; peers= [] })
  | ["options"] ->
      let%map _network = Network_request.of_yojson body in
      Respond.json
        (Network_options_response.to_yojson
           { Network_options_response.version= Version.create "1.3.1" "???"
           ; allow=
               {Allow.operation_statuses= []; operation_types= []; errors= []}
           })
  | _ ->
      Respond.error_404
