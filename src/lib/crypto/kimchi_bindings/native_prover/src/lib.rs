use neon::prelude::*;
use mina_curves::pasta::Fp;
// Import the Poseidon function and constants
use mina_poseidon::{constants::PlonkSpongeConstantsKimchi, permutation::poseidon_block_cipher, pasta::fp_kimchi};

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

fn fp_poseidon_block_cipher_native(mut cx: FunctionContext) -> JsResult<JsArray> {
  
    let js_input = cx.argument::<JsArray>(0)?;

    let n1 = arg1 as u64;
    let n2 = arg2 as u64;
    let n3 = arg3 as u64;

    // hard-coded vector: [1, 2, 3] in the Fp field
    let mut state = vec![
        Fp::from(n1),
        Fp::from(n2),
        Fp::from(n3),
    ];


    // apply the Poseidon permutation
    poseidon_block_cipher::<Fp, PlonkSpongeConstantsKimchi>(
        &fp_kimchi::static_params(),
        &mut state,
    );

    // convert to a string to return something visible to Node.js
    Ok(cx.string(format!("Poseidon Fp permutation native result: {:?}", state)))
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

    cx.export_function("fp_poseidon_block_cipher_native", fp_poseidon_block_cipher_native
    )?;
    Ok(())
}
