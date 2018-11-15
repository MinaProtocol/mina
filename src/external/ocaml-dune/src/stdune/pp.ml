type +'a t =
  | Nop
  | Seq of 'a t * 'a t
  | Concat of 'a t list
  | Box of int * 'a t
  | Vbox of int * 'a t
  | Hbox of 'a t
  | Hvbox of int * 'a t
  | Hovbox of int * 'a t
  | Int of int
  | String of string
  | Char of char
  | List : 'b t * ('a -> 'b t) * 'a list -> 'b t
  | Space
  | Cut
  | Newline
  | Text of string
  | Tag of 'a * 'a t

module type Tag = sig
  type t
  module Handler : sig
    type tag = t
    type t
    val init : t
    val handle : t -> tag -> string * t * string
  end with type tag := t
end

module Renderer = struct
  module type S = sig
    module Tag : Tag

    val string
      :  unit
      -> (?margin:int -> ?tag_handler:Tag.Handler.t -> Tag.t t -> string)
           Staged.t
    val channel
      :  out_channel
      -> (?margin:int -> ?tag_handler:Tag.Handler.t -> Tag.t t -> unit)
           Staged.t
  end

  module Make(Tag : Tag) = struct
    open Format

    module Tag = Tag

    (* The format interface only support string for tags, so we embed
       then as follow:

       - length of opening string on 16 bits
       - opening string
       - closing string
    *)
    external get16 : string -> int -> int         = "%caml_string_get16"
    external set16 : bytes  -> int -> int -> unit = "%caml_string_set16"

    let embed_tag ~opening ~closing =
      let opening_len = String.length opening  in
      let closing_len = String.length closing in
      assert (opening_len <= 0xffff);
      let buf = Bytes.create (2 + opening_len + closing_len) in
      set16 buf 0 opening_len;
      Bytes.blit_string ~src:opening ~src_pos:0 ~dst:buf ~dst_pos:2   ~len:opening_len;
      Bytes.blit_string ~src:closing ~src_pos:0 ~dst:buf ~dst_pos:(2 + opening_len) ~len:closing_len;
      Bytes.unsafe_to_string buf

    let extract_opening_tag s =
      let open_len = get16 s 0 in
      String.sub s ~pos:2 ~len:open_len

    let extract_closing_tag s =
      let pos = 2 + get16 s 0 in
      String.drop s pos

    let rec pp th ppf t =
      match t with
      | Nop -> ()
      | Seq (a, b) -> pp th ppf a; pp th ppf b
      | Concat l -> List.iter l ~f:(pp th ppf)
      | Box (indent, t) ->
        pp_open_box ppf indent;
        pp th ppf t;
        pp_close_box ppf ()
      | Vbox (indent, t) ->
        pp_open_vbox ppf indent;
        pp th ppf t;
        pp_close_box ppf ()
      | Hbox t ->
        pp_open_hbox ppf ();
        pp th ppf t;
        pp_close_box ppf ()
      | Hvbox (indent, t) ->
        pp_open_hvbox ppf indent;
        pp th ppf t;
        pp_close_box ppf ()
      | Hovbox (indent, t) ->
        pp_open_hovbox ppf indent;
        pp th ppf t;
        pp_close_box ppf ()
      | Int    x -> pp_print_int ppf x
      | String x -> pp_print_string ppf x
      | Char   x -> pp_print_char ppf x
      | List (sep, f, l) ->
        pp_print_list (fun ppf x -> pp th ppf (f x)) ppf l
          ~pp_sep:(fun ppf () -> pp th ppf sep)
      | Space -> pp_print_space ppf ()
      | Cut -> pp_print_cut ppf ()
      | Newline -> pp_force_newline ppf ()
      | Text s -> pp_print_text ppf s
      | Tag (tag, t) ->
        let opening, th, closing = Tag.Handler.handle th tag in
        pp_open_tag ppf (embed_tag ~opening ~closing);
        pp th ppf t;
        pp_close_tag ppf ()

    let setup ppf =
      let funcs = pp_get_formatter_tag_functions ppf () in
      pp_set_mark_tags ppf true;
      pp_set_formatter_tag_functions ppf
        { funcs with
          mark_open_tag  = extract_opening_tag
        ; mark_close_tag = extract_closing_tag
        }

    let string () =
      let buf = Buffer.create 1024 in
      let ppf = formatter_of_buffer buf in
      setup ppf;
      Staged.stage (fun ?(margin=80) ?(tag_handler=Tag.Handler.init) t ->
        pp_set_margin ppf margin;
        pp tag_handler ppf t;
        pp_print_flush ppf ();
        let s = Buffer.contents buf in
        Buffer.clear buf;
        s)

    let channel oc =
      let ppf = formatter_of_out_channel oc in
      setup ppf;
      Staged.stage (fun ?(margin=80) ?(tag_handler=Tag.Handler.init) t ->
        pp_set_margin ppf margin;
        pp tag_handler ppf t;
        pp_print_flush ppf ())
  end
end

module Render = Renderer.Make(struct
    type t = unit
    module Handler = struct
      type t   = unit
      let init = ()
      let handle () () = "", (), ""
    end
  end)

let pp ppf t = Render.pp () ppf t

let nop = Nop
let seq a b = Seq (a, b)
let concat l = Concat l
let box ?(indent=0) l = Box (indent, Concat l)
let vbox ?(indent=0) l = Vbox (indent, Concat l)
let hbox l = Hbox (Concat l)
let hvbox ?(indent=0) l = Hvbox (indent, Concat l)
let hovbox ?(indent=0) l = Hovbox (indent, Concat l)

let int x = Int x
let string x = String x
let char x = Char x
let list ?(sep=Cut) l ~f = List (sep, f, l)

let space = Space
let cut = Cut
let newline = Newline

let text s = Text s

let tag t ~tag = Tag (tag, t)
