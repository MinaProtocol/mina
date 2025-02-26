use neon::prelude::*;
use mina_curves::pasta::Fp;
use mina_poseidon::{
    constants::PlonkSpongeConstantsKimchi,
    permutation::poseidon_block_cipher,
    pasta::fp_kimchi,
};

fn fp_poseidon_block_cipher_native(mut cx: FunctionContext) -> JsResult<JsArray> {
    
    let js_input = cx.argument::<JsArray>(0)?;

    let val1: Handle<JsValue> = js_input.get(&mut cx, 0)?; // Explicit type
    let n1_f64 = val1.downcast_or_throw::<JsNumber, _>(&mut cx)?.value(&mut cx);
    let n1 = n1_f64 as u64;

  
    let mut state = vec![Fp::from(n1)];


    poseidon_block_cipher::<Fp, PlonkSpongeConstantsKimchi>(
        &fp_kimchi::static_params(),
        &mut state,
    );

    
    Ok(cx.string(format!(
        "Poseidon Fp permutation native result 3: {:?}",
        state
    )))
}

// The Neon module initialization
#[neon::main]
fn main(mut cx: ModuleContext) -> NeonResult<()> {
    cx.export_function(
        "fp_poseidon_block_cipher_native",
        fp_poseidon_block_cipher_native
    )?;
    Ok(())
}
