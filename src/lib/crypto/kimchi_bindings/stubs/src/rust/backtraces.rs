use backtrace::Backtrace;
use std::panic;

impl_functions! {
    pub fn init_rust_panic_hook() {
        panic::set_hook(Box::new(|info| {
            //let bt = Backtrace::new();
            //println!("Rust custom panic hook: {:?}", bt);

            if let Some(location) = info.location() {
                println!("panic occurred in file '{}' at line {}",
                    location.file(),
                    location.line(),
                );
            }

            if let Some(s) = info.payload().downcast_ref::<&str>() {
                println!("panic occurred: {s:?}");
            } else {
                println!("Rust custom panic hook: {:?}", info);
            }

        }));
    }
}
