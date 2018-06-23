open Core_kernel
open Snarky
module Impl = Snark.Make (Backends.Bn128)
open Impl
open Let_syntax

module Command = struct
  type t = Nop | Push of int | Add | Mul [@@deriving sexp]

  type var = Field.var

  (** This number is bigger than a 64bit int, but fits in the field *)
  let magic : Field.t =
    Bigint.to_field (Bigint.of_decimal_string "18446744073709551620")

  let inc x = Field.(add x (of_int 1))

  let nop_field = magic

  let add_field = inc magic

  let mul_field = inc (inc magic)

  let typ : (var, t) Typ.t =
    Typ.transport Field.typ
      ~there:(function
          | Nop -> nop_field
          | Push x -> Field.of_int x
          | Add -> add_field
          | Mul -> mul_field)
      ~back:(fun x ->
        match x with
        | _ when Field.equal x nop_field -> Nop
        | _ when Field.equal x add_field -> Add
        | _ when Field.equal x mul_field -> Mul
        | _ -> Push (Field.to_int_exn x) )

  let nopsled program size =
    assert (List.length program < size) ;
    List.init (size - List.length program) ~f:(fun _ -> Nop) @ program

  let foo = Field.add

  module Checked = struct
    let match_ : type a.
           var
        -> nop:(unit -> (unit, _) As_prover.t)
        -> push:(Field.t -> (unit, _) As_prover.t)
        -> add:(unit -> ((Field.t * Field.t) * Field.t, _) As_prover.t)
        -> mul:(unit -> ((Field.t * Field.t) * Field.t, _) As_prover.t)
        -> (unit, _) Checked.t =
     fun instr ~nop ~push ~add ~mul ->
      let%bind is_nop = Field.Checked.(equal (constant nop_field) instr) in
      let%bind is_add = Field.Checked.(equal (constant add_field) instr) in
      let%bind is_mul = Field.Checked.(equal (constant mul_field) instr) in
      let%bind is_push =
        let%map is_one = Boolean.(any [is_nop; is_mul; is_add]) in
        Boolean.not is_one
      in
      let%bind (x, y), res =
        provide_witness
          Typ.(field * field * field)
          (let open As_prover in
          let open As_prover.Let_syntax in
          let%bind is_nop = read Boolean.typ is_nop
          and is_add = read Boolean.typ is_add
          and is_mul = read Boolean.typ is_mul in
          if is_nop then
            let%map () = nop () in
            Field.((zero, zero), zero)
          else if is_add then add ()
          else if is_mul then mul ()
          else
            let%bind instr = read Field.typ instr in
            let%map () = push instr in
            Field.((zero, zero), zero))
      in
      let%bind is_add_valid =
        Field.Checked.equal res (Field.Checked.add x y)
      in
      let%bind is_mul_valid =
        let%bind res' = Field.Checked.mul x y in
        Field.Checked.equal res res'
      in
      let%bind add = Boolean.( && ) is_add_valid is_add in
      let%bind mul = Boolean.( && ) is_mul_valid is_mul in
      Boolean.Assert.any [add; mul; is_push; is_nop]
  end
end

module Vm_stack = struct
  type t = Field.t list
end

let eval instr : (unit, Vm_stack.t) Checked.t =
  let binop op =
    let open As_prover in
    let open As_prover.Let_syntax in
    match%bind get_state with
    | x :: y :: rest ->
        let res = op x y in
        let%map () = set_state (res :: rest) in
        ((x, y), res)
    | _ -> failwith "Error: Binop not enough args on stack"
  in
  Command.Checked.match_ instr
    ~nop:(fun () -> As_prover.return ())
    ~push:(fun x ->
      let open As_prover in
      let open As_prover.Let_syntax in
      let%bind stack = get_state in
      set_state (x :: stack) )
    ~mul:(fun () -> binop Field.mul)
    ~add:(fun () -> binop Field.add)

let run program : (Field.var, Vm_stack.t) Checked.t =
  let%bind () = Checked.List.iter program ~f:eval in
  provide_witness Field.typ
    (let open As_prover in
    let open As_prover.Let_syntax in
    let%map stack = get_state in
    List.hd_exn stack)

let prove_calc program output : (unit, Vm_stack.t) Checked.t =
  let%bind result = run program in
  Field.Checked.Assert.equal result output

let max_size = 25

let input () = Data_spec.[Typ.list ~length:max_size Command.typ; Field.typ]

let keypair = generate_keypair ~exposing:(input ()) prove_calc

let compile_and_validate program result =
  let program' = Command.nopsled program max_size in
  let proof =
    prove (Keypair.pk keypair) (input ()) [] prove_calc program' result
  in
  let is_valid =
    verify proof (Keypair.vk keypair) (input ()) program' result
  in
  printf
    !"*** Did I run the program %{sexp: Command.t list} to produce %{sexp: \
      Field.t}? %b\n"
    program result is_valid

(* Look it works! *)

let () =
  compile_and_validate
    Command.[Push 1; Push 1; Add; Push 1; Add; Push 2; Mul]
    (Field.of_int 6)

let () = compile_and_validate Command.[Push 20; Push 5; Mul] (Field.of_int 100)
