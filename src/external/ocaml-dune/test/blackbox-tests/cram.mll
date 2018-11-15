(* Mini implementation of cram tests *)

{
open Dune
open Import

type item =
  | Output  of string
  | Command of string
  | Comment of string
}

let eol = '\n' | eof

let ext = '.' ['a'-'z' 'A'-'Z' '0'-'9']+

rule file = parse
 | eof { [] }
 | "  $ " ([^'\n']* as str) eol { Command str :: file lexbuf }
 | "  " ([^'\n']* as str) eol   { Output  str :: file lexbuf }
 | ([^'\n']* as str) eol        { Comment str :: file lexbuf }

and postprocess tbl b = parse
  | eof { Buffer.contents b }
  | ([^ '/'] as c) (ext as e)
      { Buffer.add_char b c;
        begin match List.assoc tbl e with
        | Some res -> Buffer.add_string b res
        | None     -> Buffer.add_string b e
        end;
        postprocess tbl b lexbuf
      }
  | _ as c { Buffer.add_char b c; postprocess tbl b lexbuf }

{
  module Configurator = Configurator.V1

  let make_ext_replace config =
    let tbl =
      let var = Configurator.ocaml_config_var_exn config in
      let exts =
      [ var "ext_dll", "$ext_dll"
      ; var "ext_asm", "$ext_asm"
      ; var "ext_lib", "$ext_lib"
      ; var "ext_obj", "$ext_obj"
      ] in
      (* need to special case exe since we can only remove this extension in
         general *)
      match (
        match Configurator.ocaml_config_var config "ext_exe" with
        | Some s -> s
        | None ->
          begin match Configurator.ocaml_config_var_exn config "system" with
          | "Win32" -> ".exe"
          | _ -> ""
          end
      ) with
      | "" -> exts
      | ext -> (ext, "") :: exts
    in
    List.iter tbl ~f:(fun (e, _) -> assert (e <> ""));
    fun s ->
      let l = Lexing.from_string s in
      postprocess tbl (Buffer.create (String.length s)) l

  type version = int * int * int

  let parse_version s =
    Scanf.sscanf s "%d.%d.%d" (fun a b c -> a, b, c)

  type test =
    | Eq
    | Le
    | Ge
    | Lt
    | Gt

  let tests =
    [ "=" , Eq
    ; "<=", Le
    ; ">=", Ge
    ; "<" , Lt
    ; ">" , Gt
    ; ""  , Eq
    ]

  let test = function
    | Eq -> (=)
    | Ge -> (>=)
    | Le -> (<=)
    | Lt -> (<)
    | Gt -> (>)

  let parse_skip_versions s =
    List.map (String.split s ~on:',') ~f:(fun x ->
      Option.value_exn
        (List.find_map tests ~f:(fun (prefix, test) ->
           Option.map (String.drop_prefix x ~prefix)
             ~f:(fun x -> (test, parse_version x)))))

  let () =
    let skip_versions = ref [] in
    let expect_test = ref None in
    let args =
      [ "-skip-versions"
      , Arg.String (fun s -> skip_versions := parse_skip_versions s)
      , "Comma separated versions of ocaml where to skip test"
      ; "-test"
      , Arg.String (fun s -> expect_test := Some s)
      , "expect test file"
      ] in
    Configurator.main ~args ~name:"cram" (fun configurator ->
      let expect_test =
        match !expect_test with
        | None -> raise (Arg.Bad "expect test file must be passed")
        | Some p -> p in
      begin
        let ocaml_version =
          Configurator.ocaml_config_var_exn configurator "version"
          |> parse_version in
        if List.exists !skip_versions ~f:(fun (op, v') ->
          test op ocaml_version v') then
          exit 0;
      end;
      Test_common.run_expect_test expect_test ~f:(fun file_contents lexbuf ->
        let items = file lexbuf in
        let temp_file = Filename.temp_file "dune-test" ".output" in
        at_exit (fun () -> Sys.remove temp_file);
        let buf = Buffer.create (String.length file_contents + 1024) in
        List.iter items ~f:(function
          | Output _ -> ()
          | Comment s -> Buffer.add_string buf s; Buffer.add_char buf '\n'
          | Command s ->
            Printf.bprintf buf "  $ %s\n" s;
            let fd = Unix.openfile temp_file [O_WRONLY; O_TRUNC] 0 in
            let pid =
              Unix.create_process "sh" [|"sh"; "-c"; s|] Unix.stdin fd fd
            in
            Unix.close fd;
            let n =
              match snd (Unix.waitpid [] pid) with
              | WEXITED n -> n
              | _ -> 255
            in
            let ext_replace = make_ext_replace configurator in
            Path.of_filename_relative_to_initial_cwd temp_file
            |> Io.lines_of_file
            |> List.iter ~f:(fun line ->
              Printf.bprintf buf "  %s\n"
                (ext_replace (Ansi_color.strip line)));
            if n <> 0 then Printf.bprintf buf "  [%d]\n" n);
        Buffer.contents buf)
    )
}
