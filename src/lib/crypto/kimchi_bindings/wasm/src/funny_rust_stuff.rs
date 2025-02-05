use wasm_bindgen::prelude::*;

#[wasm_bindgen]
pub fn caml_do_cool_thingies() -> JsValue {
    return "hello from rust this is Yoni".into();
}
