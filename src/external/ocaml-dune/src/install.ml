open! Stdune
open Import

module Section = struct
  module T = struct
    type t =
      | Lib
      | Lib_root
      | Libexec
      | Libexec_root
      | Bin
      | Sbin
      | Toplevel
      | Share
      | Share_root
      | Etc
      | Doc
      | Stublibs
      | Man
      | Misc

    let compare : t -> t -> Ordering.t = compare
  end

  include T

  module Map = Map.Make(T)

  let to_string = function
    | Lib          -> "lib"
    | Lib_root     -> "lib_root"
    | Libexec      -> "libexec"
    | Libexec_root -> "libexec_root"
    | Bin          -> "bin"
    | Sbin         -> "sbin"
    | Toplevel     -> "toplevel"
    | Share        -> "share"
    | Share_root   -> "share_root"
    | Etc          -> "etc"
    | Doc          -> "doc"
    | Stublibs     -> "stublibs"
    | Man          -> "man"
    | Misc         -> "misc"

  let of_string = function
    |"lib"          -> Some Lib
    |"lib_root"     -> Some Lib_root
    |"libexec"      -> Some Libexec
    |"libexec_root" -> Some Libexec_root
    |"bin"          -> Some Bin
    |"sbin"         -> Some Sbin
    |"toplevel"     -> Some Toplevel
    |"share"        -> Some Share
    |"share_root"   -> Some Share_root
    |"etc"          -> Some Etc
    |"doc"          -> Some Doc
    |"stublibs"     -> Some Stublibs
    |"man"          -> Some Man
    |"misc"         -> Some Misc
    | _             -> None

  let decode =
    let open Dune_lang.Decoder in
    enum
      [ "lib"          , Lib
      ; "lib_root"     , Lib_root
      ; "libexec"      , Libexec
      ; "libexec_root" , Libexec_root
      ; "bin"          , Bin
      ; "sbin"         , Sbin
      ; "toplevel"     , Toplevel
      ; "share"        , Share
      ; "share_root"   , Share_root
      ; "etc"          , Etc
      ; "doc"          , Doc
      ; "stublibs"     , Stublibs
      ; "man"          , Man
      ; "misc"         , Misc
      ]

  let should_set_executable_bit = function
    | Lib
    | Lib_root
    | Toplevel
    | Share
    | Share_root
    | Etc
    | Doc
    | Man
    | Misc
      -> false
    | Libexec
    | Libexec_root
    | Bin
    | Sbin
    | Stublibs
      -> true

  module Paths = struct
    type t =
      { lib          : Path.t
      ; lib_root     : Path.t
      ; libexec      : Path.t
      ; libexec_root : Path.t
      ; bin          : Path.t
      ; sbin         : Path.t
      ; toplevel     : Path.t
      ; share        : Path.t
      ; share_root   : Path.t
      ; etc          : Path.t
      ; doc          : Path.t
      ; stublibs     : Path.t
      ; man          : Path.t
      }

    let make ~package ~destdir ?(libdir=Path.relative destdir "lib") () =
      let package = Package.Name.to_string package in
      let lib_root     = libdir                        in
      let libexec_root = libdir                        in
      let share_root   = Path.relative destdir "share" in
      let etc_root     = Path.relative destdir "etc"   in
      let doc_root     = Path.relative destdir "doc"   in
      { lib_root
      ; libexec_root
      ; share_root
      ; bin          = Path.relative destdir "bin"
      ; sbin         = Path.relative destdir "sbin"
      ; man          = Path.relative destdir "man"
      ; toplevel     = Path.relative libdir  "toplevel"
      ; stublibs     = Path.relative libdir  "stublibs"
      ; lib          = Path.relative lib_root     package
      ; libexec      = Path.relative libexec_root package
      ; share        = Path.relative share_root   package
      ; etc          = Path.relative etc_root     package
      ; doc          = Path.relative doc_root     package
      }

    let get t section =
      match section with
      | Lib          -> t.lib
      | Lib_root     -> t.lib_root
      | Libexec      -> t.libexec
      | Libexec_root -> t.libexec_root
      | Bin          -> t.bin
      | Sbin         -> t.sbin
      | Toplevel     -> t.toplevel
      | Share        -> t.share
      | Share_root   -> t.share_root
      | Etc          -> t.etc
      | Doc          -> t.doc
      | Stublibs     -> t.stublibs
      | Man          -> t.man
      | Misc         -> invalid_arg"Install.Paths.get"

    let man_subdir p =
      match Filename.split_extension_after_dot p with
      | (_, "") -> None
      | (_, man_section) -> Some ("man" ^ man_section)

    let install_path t section p =
      let section_path = get t section in
      match section with
      | Man ->
          begin
            match man_subdir p with
            | Some subdir -> Path.L.relative section_path [subdir; p]
            | None -> Path.relative section_path p
          end
      | _ -> Path.relative section_path p
  end
end

module Entry = struct
  type t =
    { src     : Path.t
    ; dst     : string option
    ; section : Section.t
    }

  let compare x y =
    let c = Path.compare x.src y.src in
    if c <> Eq then c
    else
      let c = Option.compare String.compare x.dst y.dst in
      if c <> Eq then c
      else
        Section.compare x.section y.section

  let make section ?dst src =
    let dst =
      if Sys.win32 then
        let src_base = Path.basename src in
        let dst' =
          match dst with
          | None -> src_base
          | Some s -> s
        in
        match Filename.extension src_base with
        | ".exe" | ".bc" ->
          if Filename.extension dst' <> ".exe" then
            Some (dst' ^ ".exe")
          else
            dst
        | _ -> dst
      else
        dst
    in
    { src
    ; dst
    ; section
    }

  let set_src t src = { t with src }

  let relative_installed_path t ~paths =
    let main_dir = Section.Paths.get paths t.section in
    let dst =
      match t.dst with
      | Some x -> x
      | None ->
        let dst = Path.basename t.src in
        match t.section with
        | Man -> begin
            match String.rsplit2 dst ~on:'.' with
            | None -> dst
            | Some (_, sec) -> sprintf "man%s/%s" sec dst
          end
        | _ -> dst
    in
    Path.relative main_dir dst

  let add_install_prefix t ~paths ~prefix =
    let opam_will_install_in_this_dir = Section.Paths.get paths t.section in
    let i_want_to_install_the_file_as =
      Path.append prefix (relative_installed_path t ~paths)
    in
    let dst =
      Path.reach i_want_to_install_the_file_as
        ~from:opam_will_install_in_this_dir
    in
    { t with dst = Some dst }
end

let files entries =
  List.fold_left entries ~init:Path.Set.empty ~f:(fun acc (entry : Entry.t) ->
    Path.Set.add acc entry.src)

let group entries =
  List.map entries ~f:(fun (entry : Entry.t) -> (entry.section, entry))
  |> Section.Map.of_list_multi

let gen_install_file entries =
  let buf = Buffer.create 4096 in
  let pr fmt = Printf.bprintf buf (fmt ^^ "\n") in
  Section.Map.iteri (group entries) ~f:(fun section entries ->
    pr "%s: [" (Section.to_string section);
    List.sort ~compare:Entry.compare entries
    |> List.iter ~f:(fun (e : Entry.t) ->
      let src = Path.to_string e.src in
      match e.dst with
      | None     -> pr "  %S"      src
      | Some dst -> pr "  %S {%S}" src dst);
    pr "]");
  Buffer.contents buf

let pos_of_opam_value : OpamParserTypes.value -> OpamParserTypes.pos = function
  | Bool         (pos, _)       -> pos
  | Int          (pos, _)       -> pos
  | String       (pos, _)       -> pos
  | Relop        (pos, _, _, _) -> pos
  | Prefix_relop (pos, _, _)    -> pos
  | Logop        (pos, _, _, _) -> pos
  | Pfxop        (pos, _, _)    -> pos
  | Ident        (pos, _)       -> pos
  | List         (pos, _)       -> pos
  | Group        (pos, _)       -> pos
  | Option       (pos, _, _)    -> pos
  | Env_binding  (pos, _, _, _) -> pos

let load_install_file path =
  let open OpamParserTypes in
  let file = Opam_file.load path in
  let fail (fname, line, col) fmt =
    let pos : Lexing.position =
      { pos_fname = fname
      ; pos_lnum = line
      ; pos_bol = 0
      ; pos_cnum = col
      }
    in
    Errors.fail { start =  pos; stop = pos } fmt
  in
  List.concat_map file.file_contents ~f:(function
    | Variable (pos, section, files) -> begin
        match Section.of_string section with
        | None -> fail pos "Unknown install section"
        | Some section -> begin
            match files with
            | List (_, l) ->
              List.map l ~f:(function
                | String (_, src) ->
                  { Entry.
                    src = Path.of_string src
                  ; dst = None
                  ; section
                  }
                | Option (_, String (_, src),
                          [String (_, dst)]) ->
                  { Entry.
                    src = Path.of_string src
                  ; dst = Some dst
                  ; section
                  }
                | v ->
                  fail (pos_of_opam_value v)
                    "Invalid value in .install file")
            | v ->
              fail (pos_of_opam_value v)
                "Invalid value for install section"
          end
      end
    | Section (pos, _) ->
      fail pos "Sections are not allowed in .install file")
