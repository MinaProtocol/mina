open OUnit2
open Batteries
open SpirV

let id n = "%" ^ (string_of_int @@ Int32.to_int n)

let cons_big_int ls =
  let rec loop i = function
    | h :: t ->
        let shifted_value = Big_int.shift_left_big_int (Big_int.of_int h) (i * 32) in
        Big_int.or_big_int shifted_value (loop (i - 1) t)
    | []     -> Big_int.of_int 0
  in
  loop (List.length ls - 1) ls

let binary_comparison_set_creators : (string * (unit -> op list * string)) list = [
  (* TODO test unsigned constants *)
  ("signed integer values", fun () ->
    let t_int_32 = 1l in
    let t_int_40 = 2l in
    let t_int_64 = 3l in
    let c_int_32_1 = 4l in
    let c_int_32_2 = 5l in
    let c_int_40_1 = 6l in
    let c_int_40_2 = 7l in
    let c_int_40_3 = 8l in
    let c_int_64_1 = 9l in

    [
      `OpTypeInt (t_int_32, 32l, 1l);
      `OpTypeInt (t_int_40, 40l, 1l);
      `OpTypeInt (t_int_64, 64l, 1l);

      `OpConstant (t_int_32, c_int_32_1, BigInt (Big_int.big_int_of_int 200));
      `OpConstant (t_int_32, c_int_32_2, BigInt (Big_int.big_int_of_int (-50)));
      `OpConstant (t_int_40, c_int_40_1, BigInt (Big_int.big_int_of_int 400));
      `OpConstant (t_int_40, c_int_40_2, BigInt (Big_int.big_int_of_int (-120)));
      `OpConstant (t_int_40, c_int_40_3, BigInt (cons_big_int [0x0000000f; 0xffff00ff]));
      `OpConstant (t_int_64, c_int_64_1, BigInt (cons_big_int [0x00ff0fff; 0xffff007f]))
    ], "
"^id t_int_32^"     = OpTypeInt 32 1
"^id t_int_40^"     = OpTypeInt 40 1
"^id t_int_64^"     = OpTypeInt 64 1

"^id c_int_32_1^"   = OpConstant "^id t_int_32^" 200
"^id c_int_32_2^"   = OpConstant "^id t_int_32^" -50
"^id c_int_40_1^"   = OpConstant "^id t_int_40^" 400
"^id c_int_40_2^"   = OpConstant "^id t_int_40^" -120
"^id c_int_40_3^"   = OpConstant "^id t_int_40^" 68719411455
"^id c_int_64_1^"   = OpConstant "^id t_int_64^" 71793711247196287
    "
  );
  ("unsigned integer values", fun () ->
    let t_uint_32 = 1l in
    let t_uint_64 = 2l in
    let c_uint_32_1 = 3l in
    let c_uint_32_2 = 4l in
    let c_uint_64_1 = 5l in
    let c_uint_64_2 = 6l in

    [
      `OpTypeInt (t_uint_32, 32l, 0l);
      `OpTypeInt (t_uint_64, 64l, 0l);

      `OpConstant (t_uint_32, c_uint_32_1, BigInt (Big_int.big_int_of_int 200));
      `OpConstant (t_uint_32, c_uint_32_2, BigInt (Big_int.big_int_of_int 1234567));
      `OpConstant (t_uint_64, c_uint_64_1, BigInt (cons_big_int [0x0000000f; 0xffff00ff]));
      `OpConstant (t_uint_64, c_uint_64_2, BigInt (cons_big_int [0x00ff0fff; 0xffff007f]));
    ], "
"^id t_uint_32^"     = OpTypeInt 32 0
"^id t_uint_64^"     = OpTypeInt 64 0

"^id c_uint_32_1^"   = OpConstant "^id t_uint_32^" 200
"^id c_uint_32_2^"   = OpConstant "^id t_uint_32^" 1234567
"^id c_uint_64_1^"   = OpConstant "^id t_uint_64^" 68719411455
"^id c_uint_64_2^"   = OpConstant "^id t_uint_64^" 71793711247196287
    "
  );
  ("floating point values", fun () ->
    let t_float_32 = 1l in
    let c_float_32_1 = 2l in
    let c_float_32_2 = 3l in

    [
      `OpTypeFloat (t_float_32, 32l);

      `OpConstant (t_float_32, c_float_32_1, Float 1234.5678);
      `OpConstant (t_float_32, c_float_32_2, Float (-700.568));
    ], "
"^id t_float_32^"   = OpTypeFloat 32

"^id c_float_32_1^" = OpConstant "^id t_float_32^" 1234.5678
"^id c_float_32_2^" = OpConstant "^id t_float_32^" -700.568
    "
  );
  ("string values", fun () ->
    let s_1 = 1l in
    let s_2 = 2l in
    let s_3 = 3l in
    let s_4 = 4l in
    let s_5 = 5l in
    let s_6 = 6l in
    let s_7 = 7l in
    let s_8 = 8l in
    let s_9 = 9l in

    [
      `OpString (s_1, "a");
      `OpString (s_2, "ab");
      `OpString (s_3, "abc");
      `OpString (s_4, "abcd");
      `OpString (s_5, "abcde");
      `OpString (s_6, "abcdef");
      `OpString (s_7, "abcdefg");
      `OpString (s_8, "abcdefgh");
      `OpString (s_9, "this is a really long string");
    ], "
"^id s_1^"          = OpString \"a\"
"^id s_2^"          = OpString \"ab\"
"^id s_3^"          = OpString \"abc\"
"^id s_4^"          = OpString \"abcd\"
"^id s_5^"          = OpString \"abcde\"
"^id s_6^"          = OpString \"abcdef\"
"^id s_7^"          = OpString \"abcdefg\"
"^id s_8^"          = OpString \"abcdefgh\"
"^id s_9^"          = OpString \"this is a really long string\"
    "
  );
  ("bit enums", fun () ->
    let block = 1l in
    let t_img = 2l in
    let img_1 = 3l in
    let simg = 4l in
    let coord = 5l in
    let bias = 6l in
    let img_2 = 7l in
    let c_offset = 8l in
    let grad_a = 9l in
    let grad_b = 10l in
    let img_3 = 11l in
    let sample = 12l in
    let lod = 13l in

    [
      `OpSelectionMerge (block, []);
      `OpSelectionMerge (block, [SelectionControlFlatten]);
      `OpSelectionMerge (block, [SelectionControlDontFlatten]);

      `OpImageSampleImplicitLod (t_img, img_1, simg, coord, Some [ImageOperandsBias bias]);
      `OpImageSampleImplicitLod (t_img, img_2, simg, coord, Some [ImageOperandsConstOffset c_offset; ImageOperandsGrad (grad_a, grad_b)]);
      `OpImageSampleImplicitLod (t_img, img_3, simg, coord, Some [ImageOperandsOffset c_offset; ImageOperandsSample sample; ImageOperandsMinLod lod; ImageOperandsBias bias]);
    ], "
                      OpSelectionMerge "^id block^" None
                      OpSelectionMerge "^id block^" Flatten
                      OpSelectionMerge "^id block^" DontFlatten

"^id img_1^"        = OpImageSampleImplicitLod "^id t_img^" "^id simg^" "^id coord^" Bias "^id bias^"
"^id img_2^"        = OpImageSampleImplicitLod "^id t_img^" "^id simg^" "^id coord^" ConstOffset|Grad "^id c_offset^" "^id grad_a^" "^id grad_b^"
"^id img_3^"        = OpImageSampleImplicitLod "^id t_img^" "^id simg^" "^id coord^" Offset|Sample|MinLod|Bias "^id c_offset^" "^id sample^" "^id lod^" "^id bias^"
    "
  );
  ("value enums", fun () ->
    [
      `OpSource (SourceLanguageUnknown, 0l, None, None);
      `OpSource (SourceLanguageESSL, 0l, None, None);
      `OpSource (SourceLanguageGLSL, 0l, None, None);
      `OpSource (SourceLanguageOpenCL_C, 0l, None, None);
      `OpSource (SourceLanguageOpenCL_CPP, 0l, None, None);
    ], "
      OpSource Unknown 0
      OpSource ESSL 0
      OpSource GLSL 0
      OpSource OpenCL_C 0
      OpSource OpenCL_CPP 0
    "
  );
  ("specialization operations", fun () ->
    let t_int = 1l in
    let c_c = 2l in
    let c_a = 3l in
    let c_b = 4l in

    [
      `OpSpecConstantOp (t_int, c_c, `IAdd (c_a, c_b))
    ], "
"^id c_c^"          = OpSpecConstantOp "^id t_int^" IAdd "^id c_a^" "^id c_b^"
    "
  );
  ("extended instructions", fun () ->
    let glsl = 1l in
    let t_int = 2l in
    let r = 3l in
    let c_9 = 4l in

    [
      `OpExtInstImport (glsl, "GLSL.std.450");
      `OpExtInst (t_int, r, glsl, fun () -> [0x001fl; c_9]);
    ], "
"^id glsl^"         = OpExtInstImport \"GLSL.std.450\"
"^id r^"            = OpExtInst "^id t_int^" "^id glsl^" Sqrt "^id c_9^"
    "
  );
  ("very large program", fun () ->
    let t_int = 1l in

    let statement_count = 5000l in

    let base_ops = [ `OpTypeInt (t_int, 32l, 1l) ] in

    let build_op_statement identifier =
      `OpConstant (t_int, identifier, BigInt (Big_int.big_int_of_int 256))
    in

    let base_asm_source = id t_int^" = OpTypeInt 32 1" in

    let build_asm_statement identifier =
      id identifier^" = OpConstant "^id t_int^" 256"
    in

    let build_statements fn max =
      let rec loop i =
        if i > max then [] else fn i :: loop (Int32.add i 1l)
      in
      loop 2l
    in

    let ops = base_ops @ build_statements build_op_statement statement_count in
    let asm_source = base_asm_source ^ "\n" ^ (String.concat "\n" @@ build_statements build_asm_statement statement_count) in

    (ops, asm_source)
  );
  ("copy.spv", fun () ->
    let func = 1l in
    let v_in = 2l in
    let v_out = 3l in
    let v_g_index = 4l in
    let t_struct = 5l in
    let t_in_arr = 6l in
    let t_void = 7l in
    let t_func = 8l in
    let t_int = 9l in
    let c_zero = 10l in
    let c_in_sz = 11l in
    let t_vec = 12l in
    let t_u_struct_p = 13l in
    let t_u_int_p = 14l in
    let t_in_vec_p = 15l in
    let t_in_int_p = 16l in
    let label = 17l in
    let g_index_p = 18l in
    let g_index = 19l in
    let in_p = 20l in
    let out_p = 21l in
    let input = 22l in

    [
      `OpCapability CapabilityShader;
      `OpMemoryModel (AddressingModelLogical, MemoryModelSimple);
      `OpEntryPoint (ExecutionModelGLCompute, func, "f", [v_in; v_out; v_g_index]);
      `OpExecutionMode (func, ExecutionModeLocalSize (1l, 1l, 1l));

      `OpDecorate (t_struct, DecorationBufferBlock);
      `OpDecorate (v_g_index, DecorationBuiltIn BuiltInGlobalInvocationId);
      `OpDecorate (v_in, DecorationDescriptorSet 0l);
      `OpDecorate (v_in, DecorationBinding 0l);
      `OpDecorate (v_out, DecorationDescriptorSet 0l);
      `OpDecorate (v_out, DecorationBinding 1l);
      `OpDecorate (t_in_arr, DecorationArrayStride 4l);
      `OpMemberDecorate (t_struct, 0l, DecorationOffset 0l);

      `OpTypeVoid t_void;
      `OpTypeFunction (t_func, t_void, []);
      `OpTypeInt (t_int, 32l, 1l);

      `OpConstant (t_int, c_zero, BigInt (Big_int.big_int_of_int 0));
      `OpConstant (t_int, c_in_sz, BigInt (Big_int.big_int_of_int 2048));

      `OpTypeArray (t_in_arr, t_int, c_in_sz);
      `OpTypeStruct (t_struct, [t_in_arr]);
      `OpTypeVector (t_vec, t_int, 3l);
      `OpTypePointer (t_u_struct_p, StorageClassUniform, t_struct);
      `OpTypePointer (t_u_int_p, StorageClassUniform, t_int);
      `OpTypePointer (t_in_vec_p, StorageClassInput, t_vec);
      `OpTypePointer (t_in_int_p, StorageClassInput, t_int);

      `OpVariable (t_u_struct_p, v_in, StorageClassUniform, None);
      `OpVariable (t_u_struct_p, v_out, StorageClassUniform, None);
      `OpVariable (t_u_struct_p, v_g_index, StorageClassInput, None);

      `OpFunction (t_void, func, [FunctionControlNone], t_func);
      `OpLabel label;
      `OpAccessChain (t_in_int_p, g_index_p, v_g_index, [c_zero]);
      `OpLoad (t_int, g_index, g_index_p, None);
      `OpAccessChain (t_u_int_p, in_p, v_in, [c_zero; g_index]);
      `OpAccessChain (t_u_int_p, out_p, v_out, [c_zero; g_index]);
      `OpLoad (t_int, input, in_p, None);
      `OpStore (out_p, input, None);
      `OpReturn;
      `OpFunctionEnd
    ], "
                      OpCapability Shader
                      OpMemoryModel Logical Simple
                      OpEntryPoint GLCompute "^id func^" \"f\" "^id v_in^" "^id v_out^" "^id v_g_index^"
                      OpExecutionMode "^id func^" LocalSize 1 1 1

                      OpDecorate "^id t_struct^" BufferBlock
                      OpDecorate "^id v_g_index^" BuiltIn GlobalInvocationId
                      OpDecorate "^id v_in^" DescriptorSet 0
                      OpDecorate "^id v_in^" Binding 0
                      OpDecorate "^id v_out^" DescriptorSet 0
                      OpDecorate "^id v_out^" Binding 1
                      OpDecorate "^id t_in_arr^" ArrayStride 4
                      OpMemberDecorate "^id t_struct^" 0 Offset 0

"^id t_void^"       = OpTypeVoid
"^id t_func^"       = OpTypeFunction "^id t_void^"
"^id t_int^"        = OpTypeInt 32 1

"^id c_zero^"       = OpConstant "^id t_int^" 0
"^id c_in_sz^"      = OpConstant "^id t_int^" 2048

"^id t_in_arr^"     = OpTypeArray "^id t_int^" "^id c_in_sz^"
"^id t_struct^"     = OpTypeStruct "^id t_in_arr^"
"^id t_vec^"        = OpTypeVector "^id t_int^" 3
"^id t_u_struct_p^" = OpTypePointer Uniform "^id t_struct^"
"^id t_u_int_p^"    = OpTypePointer Uniform "^id t_int^"
"^id t_in_vec_p^"   = OpTypePointer Input "^id t_vec^"
"^id t_in_int_p^"   = OpTypePointer Input "^id t_int^"

"^id v_in^"         = OpVariable "^id t_u_struct_p^" Uniform
"^id v_out^"        = OpVariable "^id t_u_struct_p^" Uniform
"^id v_g_index^"    = OpVariable "^id t_u_struct_p^" Input

"^id func^"         = OpFunction "^id t_void^" None "^id t_func^"
"^id label^"        = OpLabel
"^id g_index_p^"    = OpAccessChain "^id t_in_int_p^" "^id v_g_index^" "^id c_zero^"
"^id g_index^"      = OpLoad "^id t_int^" "^id g_index_p^"
"^id in_p^"         = OpAccessChain "^id t_u_int_p^" "^id v_in^" "^id c_zero^" "^id g_index^"
"^id out_p^"        = OpAccessChain "^id t_u_int_p^" "^id v_out^" "^id c_zero^" "^id g_index^"
"^id input^"        = OpLoad "^id t_int^" "^id in_p^"
                      OpStore "^id out_p^" "^id input^"
                      OpReturn
                      OpFunctionEnd
    "
  );
]

(*
let validation_exception_set_creators = [
  ("result types must be defined", fun () ->
    [
    ], Id_not_defined (t_int)
  )
];
*)

let string_of_word = Printf.sprintf "0x%08lx"

let pp_diff_words f (expected, actual) =
  let open Format in
  let mark a b = if a = b then "O" else "X" in
  let rec loop = function
    | (ah :: at, bh :: bt) ->
      pp_print_string f ("| " ^ mark ah bh ^ " | " ^ string_of_word ah ^ " | " ^ string_of_word bh ^ " |");
      pp_force_newline f ();
      loop (at, bt)
    | (ah :: at, [])       ->
      pp_print_string f ("| X | " ^ string_of_word ah ^ " |            |");
      pp_force_newline f ();
      loop (at, [])
    | ([], bh :: bt)       ->
      pp_print_string f ("| X |            | " ^ string_of_word bh ^ " |");
      pp_force_newline f ();
      loop ([], bt)
    | ([], [])             -> ()
  in
  let cap = "===============================" in
  pp_force_newline f ();
  pp_print_string f cap;
  pp_force_newline f ();
  pp_print_string f "|   |  Expected  |   Actual   |";
  pp_force_newline f ();
  pp_print_string f cap;
  pp_force_newline f ();
  loop (expected, actual);
  pp_print_string f cap;
  pp_force_newline f ()

(*
let disassemble_words words =
  let rec write_words ch = function
    | h :: t -> (IO.write_real_i32 ch h; write_words ch t)
    | []     -> ()
  in

  let (in_ch, out_ch) = Unix.open_process "spirv-dis --raw-id -" in
  write_words out_ch words;
  let str = IO.read_all in_ch in
  if Unix.close_process (in_ch, out_ch) = Unix.WEXITED 0 then
    str
  else
    "Disassembly error: " ^ str
*)

let build_binary_comparison_test (name, fn) =
  let (ops, asm_source) = fn () in
  let rec read_all_with fn ch =
    try
      let value = fn ch in
      value :: read_all_with fn ch
    with
      | IO.No_more_input -> []
  in
  let check_status = function
    | Unix.WEXITED 0   -> ()
    | Unix.WEXITED n   -> assert_failure (Printf.sprintf "spirv-as exited with %d" n)
    | Unix.WSIGNALED n -> assert_failure (Printf.sprintf "spirv-as was killed by signal with exit code %d" n)
    | Unix.WSTOPPED n  -> assert_failure (Printf.sprintf "spirv-as was stopped by signal with exit code %d" n)
  in
  let fix_dynamic_header_elements = function
    (* replaces generator code and id cap *)
    | (ma :: va :: ga :: ca :: ta, mb :: vb :: _ :: _ :: tb) ->
        (ma :: va :: ga :: ca :: ta, mb :: vb :: ga :: ca :: tb)
    | _ -> failwith "trim_gen_code called on invalid list"
  in
  name >:: fun _ -> begin
    let op_words = compile_to_words ops in
    (* let (in_ch, out_ch) = Unix.open_process (Printf.sprintf "echo '%s'spirv-as -o - -" asm_source) in *)
    let in_ch = Unix.open_process_in (Printf.sprintf "echo '%s' | spirv-as --target-env spv1.1 -o - -" asm_source) in
    (* IO.write_string out_ch asm_source; *)
    let asm_words = read_all_with IO.read_real_i32 in_ch in
    check_status @@ Unix.close_process_in in_ch;
    let (op_words, asm_words) = fix_dynamic_header_elements (op_words, asm_words) in
    assert_equal ~pp_diff:pp_diff_words asm_words op_words
  end

(*
let build_validation_exception_test (name, fn) =
  let (ops, expected_error) = fn () in
  name >:: fun _ -> assert_raises expected_error (fun () -> compile_to_words ops)
*)

let suite = "SpirV" >::: [
  "binary comparisons" >::: List.map build_binary_comparison_test binary_comparison_set_creators
  (* "validation exceptions" >::: List.map build_validation_exception_test validation_exception_set_creators *)
]

let _ = run_test_tt_main suite
