(** {1 Branch Data - Proof System Branch and Domain Encoding}

    This module encodes information about which branch of a proof system
    was taken and what domain size was used. This data is packed into a
    single field element for efficient circuit representation.

    {2 Purpose}

    When a proof system has multiple branches (inductive rules), the
    verifier needs to know:
    1. How many proofs were verified (0, 1, or 2)
    2. What domain size was used for the circuit

    This information is packed into 10 bits:
    - 2 bits for [proofs_verified] (as a prefix mask)
    - 8 bits for [domain_log2] (log2 of domain size)

    {2 Structure}

    {v
    type t = {
      proofs_verified : Proofs_verified.t  (* N0, N1, or N2 *)
      domain_log2 : Domain_log2.t          (* 8-bit value *)
    }
    v}

    {2 Checked Variants}

    Two checked variants exist for use in circuits:
    - [Checked.Step]: For step circuits (Tick field)
    - [Checked.Wrap]: For wrap circuits (Tock field)

    Each provides a [pack] function to combine into a single field element.

    {2 Packing Format}

    The packed field element contains:
    {v
    | proofs_verified_mask (2 bits) | domain_log2 (8 bits) |
    v}

    {2 Implementation Notes for Rust Port}

    - Use a struct with two fields, impl pack/unpack methods
    - Proofs_verified is an enum {N0, N1, N2}
    - Domain_log2 is a u8 (8 bits)
    - Pack uses bit shifting: (mask << 8) | domain_log2

    @see {!Proofs_verified} for the proof count encoding
    @see {!Composition_types} for where branch_data is used
*)

include
  Branch_data_intf.S
    with type Domain_log2.Stable.V1.t =
      Mina_wire_types.Pickles_composition_types.Branch_data.Domain_log2.V1.t
     and type Stable.V1.t =
      Mina_wire_types.Pickles_composition_types.Branch_data.V1.t
