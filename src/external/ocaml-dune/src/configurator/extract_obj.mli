(** Read and extract the strings between a pair of BEGIN-\d+- and -END
    delimiters. This is used to extract the copmile time values from .obj
    files *)
val extract : (int * string) list -> Lexing.lexbuf -> (int * string) list
