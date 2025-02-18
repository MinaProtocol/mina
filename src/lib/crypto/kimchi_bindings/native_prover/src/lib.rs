use neon::prelude::*;
use mina_curves::pasta::Fp;
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

fn caml_do_cool_thingies(mut cx: FunctionContext) -> JsResult<JsString> {
    // Directly create a `JsString` 
    Ok(cx.string("hello from native rust this is Yoni"))
}

// This takes a Vec<Fp>, applies the Poseidon permutation in place, returns the mutated Vec
fn pasta_fp_poseidon_block_cipher(mut state: Vec<Fp>) -> Vec<Fp> {
    poseidon_block_cipher::<Fp, PlonkSpongeConstantsKimchi>(
        mina_poseidon::pasta::fp_kimchi::static_params(),
        &mut state,
    );
    state
}

// The Neon module initialization
#[neon::main]
fn main(mut cx: ModuleContext) -> NeonResult<()> {
    // Export the JS function name ("caml_do_cool_thingies") 
    // and map it to our Rust function
    cx.export_function("caml_do_cool_thingies", caml_do_cool_thingies)?;
    Ok(())
}