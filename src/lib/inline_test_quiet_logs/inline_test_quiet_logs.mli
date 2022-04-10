module Ppx_inline_test_lib : sig
  module Runtime : sig
    module Test_result = Ppx_inline_test_lib__Runtime.Test_result

    type config = (module Inline_test_config.S)

    type 'a test_function_args =
         config:config
      -> descr:string
      -> tags:string list
      -> filename:string
      -> line_number:int
      -> start_pos:int
      -> end_pos:int
      -> 'a

    val set_lib_and_partition : string -> string -> unit

    val unset_lib : string -> unit

    (*val summarize : unit -> Ppx_inline_test_lib__Runtime.Test_result.t*)

    val collect : (unit -> unit) -> (unit -> unit) list

    val testing :
      [ `Not_testing
      | `Testing of [ `Am_child_of_test_runner | `Am_test_runner ] ]

    val use_color : bool

    val in_place : bool

    val diff_command : string option

    val source_tree_root : string option

    val allow_output_patterns : bool

    val am_running_inline_test : bool

    val am_running_inline_test_env_var : string

    val add_evaluator :
      f:(unit -> Ppx_inline_test_lib__Runtime.Test_result.t) -> unit

    val exit : unit -> 'a

    val redirect_to_newfile : unit -> string * out_channel * Unix.file_descr

    val tidy_up :
      dump_out:bool -> string * out_channel * Unix.file_descr -> unit

    val test :
         config:config
      -> descr:string
      -> tags:string list
      -> filename:string
      -> line_number:int
      -> start_pos:int
      -> end_pos:int
      -> (unit -> bool)
      -> unit

    val test_unit :
         config:config
      -> descr:string
      -> tags:string list
      -> filename:string
      -> line_number:int
      -> start_pos:int
      -> end_pos:int
      -> (unit -> unit)
      -> unit

    val test_module :
         config:config
      -> descr:string
      -> tags:string list
      -> filename:string
      -> line_number:int
      -> start_pos:int
      -> end_pos:int
      -> (unit -> unit)
      -> unit
  end
end
