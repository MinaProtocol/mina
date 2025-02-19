use neon::prelude::*;
use mina_curves::pasta::Fp;
// Import the Poseidon function and constants
use mina_poseidon::{constants::PlonkSpongeConstantsKimchi, permutation::poseidon_block_cipher};

// // 
// fn caml_do_cool_thingies() -> String {
//     "hello from native rust this is Yoni".into()
// }

// Neon-friendly entry point
// fn caml_do_cool_thingies_js(mut cx: FunctionContext) -> JsResult<JsString> {
//     // call the pure Rust function
//     let result: String = caml_do_cool_thingies();

//     // Convert the `String` into a Neon `JsString`
//     Ok(cx.string(result))
// }

fn caml_pasta_fp_poseidon_block_cipher_js(mut cx: FunctionContext) -> JsResult<JsString> {
    // hard-coded vector: [1, 2, 3] in the Fp field
    let mut state = vec![
        Fp::from(1u64),
        Fp::from(2u64),
        Fp::from(3u64),
    ];


    // apply the Poseidon permutation
    poseidon_block_cipher::<Fp, PlonkSpongeConstantsKimchi>(
        &fp_kimchi::static_params(),
        &mut state,
    );

    // convert to a string to return something visible to Node.js
    Ok(cx.string(format!("Poseidon Fp permutation result: {:?}", state)))
}

fn caml_do_cool_thingies(mut cx: FunctionContext) -> JsResult<JsString> {
    // Directly create a `JsString` 
    Ok(cx.string("hello from native rust this is Yoni"))
}

// The Neon module initialization
#[neon::main]
fn main(mut cx: ModuleContext) -> NeonResult<()> {
    // Export the JS function name ("caml_do_cool_thingies") 
    // and map it to our Rust function
    cx.export_function("caml_do_cool_thingies", caml_do_cool_thingies)?;

    cx.export_function("fp_poseidon_block_cipher", caml_pasta_fp_poseidon_block_cipher_js
    )?;
    Ok(())
}
