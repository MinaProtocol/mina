open Core
open Async

let send_payment logger = 
    Logger.info logger ~module_:__MODULE__ ~location:__LOC__ "send_payment called";
    Command.exit 0
  

let client logger =
  Command.group ~summary:"Lightweight client commands"
    ~preserve_subcommand_order:()
    [
    ("send-payment", send_payment logger);
    ]

    let saffron_commands logger  = [
      ("client", client logger);
      ]

let print_version_help coda_exe version =
  (* mimic Jane Street command help *)
  let lines =
    [ "print version information"
    ; ""
    ; sprintf "  %s %s" (Filename.basename coda_exe) version
    ; ""
    ; "=== flags ==="
    ; ""
    ; "  [-help]  print this help text and exit"
    ; "           (alias: -?)"
    ]
  in
  List.iter lines ~f:(Core.printf "%s\n%!")

let print_version_info () = Core.printf "Commit %s\n" "1"

let () =
  Random.self_init () ;
  let logger = Logger.create () in
  (let is_version_cmd s =
     List.mem [ "version"; "-version"; "--version" ] s ~equal:String.equal
   in
   match Sys.get_argv () with
   | [| _mina_exe; version |] when is_version_cmd version ->
        print_version_info ()
   | _ ->
       Command.run
         (Command.group ~summary:"Saffron" 
            (saffron_commands logger) )
  ) ;
  Core.exit 0

let linkme = ()
