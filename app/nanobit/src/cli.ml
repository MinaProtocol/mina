open Core
open Async

let int16 =
  let max_port = 1 lsl 16 in
  Command.Arg_type.map Command.Param.int ~f:(fun x ->
    if 0 <= x && x < max_port
    then x
    else failwithf "Port not between 0 and %d" max_port ())

let () =
  let open Command.Let_syntax in
  Command.async
    ~summary:"Current daemon"
    begin
      [%map_open
        let conf_dir =
          flag "config directory"
            ~doc:"Configuration directory"
            (optional file)
        and should_mine =
          flag "mine"
            ~doc:"Run the miner" (required bool)
        and port =
          flag "port"
            ~doc:"Server port for other to connect" (required int16)
        and ip =
          flag "ip"
            ~doc:"External IP address for others to connect" (required string)
        in
        fun () ->
          let open Deferred.Let_syntax in
          let%bind home = Sys.home_directory () in
          let conf_dir =
            Option.value ~default:(home ^/ ".current-config") conf_dir
          in
          let%bind initial_peers =
            match%bind Reader.load_sexp conf_dir [%of_sexp: Host_and_port.t list] with
            | Ok ls -> return ls
            | Error e -> 
              begin
                let default_initial_peers = [] in
                let%map () = Writer.save_sexp conf_dir ([%sexp_of: Host_and_port.t list] default_initial_peers) in
                []
              end
          in
          Main.main (conf_dir ^/ "storage") Blockchain.genesis initial_peers should_mine
            (Host_and_port.create ~host:ip ~port)
      ]
    end
  |> Command.run
;;
