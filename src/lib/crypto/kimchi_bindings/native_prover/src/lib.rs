use neon::prelude::*;

// // 
// fn caml_do_cool_thingies() -> String {
//     "hello from native rust this is Yoni".into()
// }

// // Neon-friendly entry point
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

// The Neon module initialization
#[neon::main]
fn main(mut cx: ModuleContext) -> NeonResult<()> {
    // Export the JS function name ("caml_do_cool_thingies") 
    // and map it to our Rust function
    cx.export_function("caml_do_cool_thingies", caml_do_cool_thingies)?;
    Ok(())
}