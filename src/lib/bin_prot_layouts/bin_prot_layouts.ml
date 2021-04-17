(* bin_prot_layouts.ml -- layouts for imported types *)

(* the serialization is via Of_stringable *)
let inet_addr_v1_layout =
  { Ppx_version_runtime.Bin_prot_layout.layout_loc= "None"
  ; version_opt= None
  ; type_decl= "Core.Unix.Inet_addr.Stable.V1.t"
  ; bin_io_derived= false
  ; bin_prot_rule= Ppx_version_runtime.Bin_prot_rule.String }

(* TODO: what's the actual rule here? *)
let unshifted_accumulators =
  { Ppx_version_runtime.Bin_prot_layout.layout_loc= "None"
  ; version_opt= None
  ; type_decl= "'a Shift.Map.t"
  ; bin_io_derived= false
  ; bin_prot_rule= Ppx_version_runtime.Bin_prot_rule.String }

let core_kernel_time =
  { Ppx_version_runtime.Bin_prot_layout.layout_loc= "None"
  ; version_opt= None
  ; type_decl= "Core_kernel.Time.t"
  ; bin_io_derived= true
  ; bin_prot_rule= Ppx_version_runtime.Bin_prot_rule.Float }

let core_time_stable_v1 =
  { Ppx_version_runtime.Bin_prot_layout.layout_loc= "None"
  ; version_opt= None
  ; type_decl= "Core.Time.Stable.V1.t"
  ; bin_io_derived= true
  ; bin_prot_rule= Ppx_version_runtime.Bin_prot_rule.Float }

let core_kernel_option_stable_v1 =
  { Ppx_version_runtime.Bin_prot_layout.layout_loc= "None"
  ; version_opt= None
  ; type_decl= "Core_kernel.Option.Stable.V1.t"
  ; bin_io_derived= true
  ; bin_prot_rule=
      Ppx_version_runtime.Bin_prot_rule.(
        Type_abstraction (["a"], Option (Type_var "a"))) }

let core_kernel_string_stable_v1 =
  { Ppx_version_runtime.Bin_prot_layout.layout_loc= "None"
  ; version_opt= None
  ; type_decl= "Core_kernel.Option.Stable.V1.t"
  ; bin_io_derived= true
  ; bin_prot_rule= Ppx_version_runtime.Bin_prot_rule.String }

(* TODO: what is the real rule? *)
let core_kernel_md5_stable_v1 =
  { Ppx_version_runtime.Bin_prot_layout.layout_loc= "None"
  ; version_opt= None
  ; type_decl= "Core_kernel.Md5.Stable.V1.t"
  ; bin_io_derived= true
  ; bin_prot_rule= Ppx_version_runtime.Bin_prot_rule.String }

let int64 =
  { Ppx_version_runtime.Bin_prot_layout.layout_loc= "None"
  ; version_opt= None
  ; type_decl= "Core_kernel.Int64.t"
  ; bin_io_derived= true
  ; bin_prot_rule= Ppx_version_runtime.Bin_prot_rule.Int64 }

let core_kernel_list_v1 =
  { Ppx_version_runtime.Bin_prot_layout.layout_loc= "None"
  ; version_opt= None
  ; type_decl= "'a Core_kernel.List.Stable.V1.t"
  ; bin_io_derived= true
  ; bin_prot_rule=
      Ppx_version_runtime.Bin_prot_rule.(
        Type_abstraction (["a"], List (Type_var "a"))) }

let core_kernel_bigstring_v1 =
  { Ppx_version_runtime.Bin_prot_layout.layout_loc= "None"
  ; version_opt= None
  ; type_decl= "Core_kernel.Bigstring.Stable.V1.t"
  ; bin_io_derived= true
  ; bin_prot_rule= Ppx_version_runtime.Bin_prot_rule.Bigstring }

(* TODO: what are the key, value rules? *)
let snark_work_statement_v1_table =
  { Ppx_version_runtime.Bin_prot_layout.layout_loc= "None"
  ; version_opt= None
  ; type_decl=
      "(Ledger_proof.Stable.V1.t One_or_two.Stable.V1.t \
       Priced_proof.Stable.V1.t  * [ `Rebroadcastable of \
       Core.Time.Stable.With_utc_sexp.V2.t | `Not_rebroadcastable ] ) \
       Transaction_snark_work.Statement.Stable.V1.Table.t"
  ; bin_io_derived= true
  ; bin_prot_rule=
      Ppx_version_runtime.Bin_prot_rule.(
        Hashtable {key_rule= String; value_rule= String}) }
