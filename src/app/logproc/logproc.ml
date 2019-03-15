open Core

let find_timezone () =
  let ch = Unix.open_process_in {|date +"%z"|} in
  let input = Option.value_exn (In_channel.input_line ch) in
  In_channel.close ch ;
  Time.Zone.of_utc_offset ~hours:(int_of_string input / 100)

let format_timestamp ~timezone time =
  let date, of_day = Time.to_date_ofday ~zone:timezone time in
  sprintf "%d-%d-%d %s" (Date.year date)
    (Month.to_int (Date.month date))
    (Date.day date)
    (Time.Ofday.to_string of_day)

let level_color =
  let open Bash_colors in
  let open Logger.Level in
  function
  | Trace -> cyan
  | Debug -> green
  | Info -> magenta
  | Warn -> yellow
  | Error -> red
  | Faulty_peer -> orange
  | Fatal -> bright_red

let format_msg ~interpolation_config ~timezone msg =
  let open Logger.Message in
  (* TODO: interpolation/formatting options *)
  let message, extra =
    match
      Interpolator.interpolate interpolation_config msg.message msg.metadata
    with
    | Ok x -> x
    | Error err ->
        let open Bash_colors in
        printf
          !"%s===== Error interpolating message: %s%s\n%!"
          bright_red err none ;
        (msg.message, [])
  in
  printf !"%s[%s]%s: %s%s\n" (level_color msg.level)
    (format_timestamp ~timezone msg.timestamp)
    msg.source.module_ message Bash_colors.none ;
  List.iter extra ~f:(fun (k, v) -> printf !"$%s = %s\n" k v) ;
  Out_channel.(flush stdout)

let yojson_from_string_result str =
  try Ok (Yojson.Safe.from_string str) with exn ->
    print_string "exn!" ;
    Error (Exn.to_string exn)

let process_line ~timezone ~interpolation_config ~filter line =
  let open Result.Let_syntax in
  match
    let%bind json = yojson_from_string_result line in
    let%map msg = Logger.Message.of_yojson json in
    (json, msg)
  with
  | Error err -> printf !"ERROR PROCESSING LINE: %s\n%!" err
  | Ok (json, msg) ->
      if Filter.Interpreter.matches filter json then
        format_msg ~timezone ~interpolation_config msg

(* TODO: check for common filter errors (e.g. invalid level provided) *)
let main timezone_str interpolation_config filter_str =
  let filter =
    if filter_str = "" then Result.ok_or_failwith (Filter.Parser.parse "true")
    else
      let error s =
        eprintf !"ERROR PARSING FILTER: %s\n%!" s ;
        exit 1
      in
      match
        try Filter.Parser.parse filter_str with exn ->
          error (Exn.to_string exn)
      with
      | Ok x -> x
      | Error err -> error err
  in
  (* let filter = Result.ok_or_failwith (Filter.Parser.parse "true") in *)
  (* let filter = Result.ok_or_failwith (Filter.Parser.parse ".level === \"Info\"") in *)
  let timezone =
    if timezone_str = "" then find_timezone ()
    else Time.Zone.of_string timezone_str
  in
  In_channel.(
    iter_lines stdin ~f:(process_line ~timezone ~interpolation_config ~filter))

let () =
  let open Cmdliner in
  (* default: inline *)
  (* -i --interpolation-mode: hidden, inline, after *)
  (* -m --max-interpolation-length *)
  (* -p --pretty-print *)
  let interpolation_config =
    let interpolation_mode =
      let open Interpolator in
      let doc = "Set how interpolation of messages will be performed" in
      Arg.(
        value
        & opt
            (enum [("hidden", Hidden); ("inline", Inline); ("after", After)])
            Inline
        & info ["i"; "interpolation-mode"] ~docv:"MODE" ~doc)
    in
    let max_interpolation_length =
      let doc =
        "Maximum allowed length of interpolated values. Values exceeding this \
         length will be replaced with \"(...)\"."
      in
      Arg.(
        value & opt int 25
        & info
            ["m"; "max-interpolation-length"]
            ~docv:"MAX_INTERPOLATION_LENGTH" ~doc)
    in
    let pretty_print =
      let doc = "Pretty print json values." in
      Arg.(value & flag & info ["p"; "pretty-print"] ~docv:"PRETTY_PRINT" ~doc)
    in
    let lift_interpolation_config mode max_interpolation_length pretty_print =
      let open Interpolator in
      {mode; max_interpolation_length; pretty_print}
    in
    Term.(
      const lift_interpolation_config
      $ interpolation_mode $ max_interpolation_length $ pretty_print)
  in
  let timezone =
    let doc = "Timezone to display timestamps in." in
    Arg.(value & opt string "" & info ["z"; "zone"] ~docv:"TIMEZONE" ~doc)
  in
  let filter =
    let doc = "Filter displayed log lines." in
    Arg.(value & opt string "" & info ["f"; "filter"] ~docv:"FILTER" ~doc)
  in
  let main_term =
    Term.(const main $ timezone $ interpolation_config $ filter)
  in
  let main_info =
    let doc = "Process coda log statements from standard input" in
    let man = [`P "this is a test of the man page"] in
    Term.info ~version:"%%VERSION%%" ~doc ~exits:Term.default_exits ~man
      "logproc"
  in
  Term.(exit @@ eval (main_term, main_info))
