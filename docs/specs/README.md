# Types and structures

* [Common](types_and_structures/common.md)
* [Serialized key](types_and_structures/serialized_key.md)
* [Serialized SRS](types_and_structures/serialized_srs.md)
* [Block structure](types_and_structures/block.md)

# Loading the URS

**Inputs:**
* `path` to the serialized URS file
* `offset` of binary URS within file

**Outputs**
* `Result<Option<CamlPastaFpUrs>, ocaml::Error>`

```rust
pub fn caml_pasta_fp_urs_read(
    offset: Option<ocaml::Int>,
    path: String,
) -> Result<Option<CamlPastaFpUrs>, ocaml::Error>
```

# Loading the verifier keys

**Inputs**
* `path: String` to serialized verifier key file
* `URS: CamlPastaFpUrs` loaded

**Outputs**
* `Result<CamlPastaFpPlonkVerifierIndex, ocaml::Error>`

**Spec**

1. Open the serialized key `path`
2. Read and parse the `header` (see the [serialized key format](types_and_structures/serialized_key.md))
3. Compute the offset of the `body`
4. Validate the `header` against the metadata provided by O(1) Labs in the verifier key filename
    1. `header.kind.type`
    2. `header.kind.identifier`
    3. `header.constraint_system_hash`
5. Load the key using `caml_pasta_fp_plonk_verifier_index_read` with the `path, offset` and `URS`

```rust
use crate::caml_pasta_fp_plonk_verifier_index;

fn caml_pasta_fp_plonk_verifier_index_read(
    offset: Option<ocaml::Int>,
    urs: CamlPastaFpUrs,
    path: String,
) -> Result<CamlPastaFpPlonkVerifierIndex, ocaml::Error>
```
6. Validate the `header` against the loaded key contents
    1. `constraint_constants`
    2. `constraint_system_hash`
