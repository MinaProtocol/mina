#![allow(clippy::manual_map)]
extern crate proc_macro;

use proc_macro::TokenStream;
use quote::quote;

mod derive;

fn check_func(item_fn: &mut syn::ItemFn) {
    if item_fn.sig.asyncness.is_some() {
        panic!("OCaml functions cannot be async");
    }

    if item_fn.sig.variadic.is_some() {
        panic!("OCaml functions cannot be variadic");
    }

    match item_fn.vis {
        syn::Visibility::Public(_) => (),
        _ => panic!("OCaml functions must be public"),
    }

    if !item_fn.sig.generics.params.is_empty() {
        panic!("OCaml functions may not contain generics")
    }

    item_fn.sig.abi = Some(syn::Abi {
        extern_token: syn::token::Extern::default(),
        name: Some(syn::LitStr::new("C", item_fn.sig.ident.span())),
    });
}

/// `func` is used export Rust functions to OCaml, performing the necessary wrapping/unwrapping
/// automatically.
///
/// - Wraps the function body using `ocaml::body`
/// - Automatic type conversion for arguments/return value (including Result types)
/// - Defines a bytecode function automatically for functions that take more than 5 arguments. The
/// bytecode function for `my_func` would be `my_func_bytecode`
/// - Allows for an optional ident argument specifying the name of the `gc` handle parameter
#[proc_macro_attribute]
pub fn ocaml_func(attribute: TokenStream, item: TokenStream) -> TokenStream {
    let mut item_fn: syn::ItemFn = syn::parse(item).unwrap();
    check_func(&mut item_fn);

    let name = &item_fn.sig.ident;
    let unsafety = &item_fn.sig.unsafety;
    let constness = &item_fn.sig.constness;
    let mut gc_name = syn::Ident::new("gc", name.span());
    let mut use_gc = quote!({let _ = &#gc_name;});
    if let Ok(ident) = syn::parse::<syn::Ident>(attribute) {
        gc_name = ident;
        use_gc = quote!();
    }

    let (returns, rust_return_type) = match &item_fn.sig.output {
        syn::ReturnType::Default => (false, None),
        syn::ReturnType::Type(_, t) => (true, Some(t)),
    };

    let rust_args: Vec<_> = item_fn.sig.inputs.iter().collect();

    let args: Vec<_> = item_fn
        .sig
        .inputs
        .iter()
        .map(|arg| match arg {
            syn::FnArg::Receiver(_) => panic!("OCaml functions cannot take a self argument"),
            syn::FnArg::Typed(t) => match t.pat.as_ref() {
                syn::Pat::Ident(ident) => Some(ident),
                _ => None,
            },
        })
        .collect();

    let mut ocaml_args: Vec<_> = args
        .iter()
        .map(|t| match t {
            Some(ident) => {
                let ident = &ident.ident;
                quote! { #ident: ocaml::Raw }
            }
            None => quote! { _: ocaml::Raw },
        })
        .collect();

    let param_names: syn::punctuated::Punctuated<syn::Ident, syn::token::Comma> = args
        .iter()
        .filter_map(|arg| match arg {
            Some(ident) => Some(ident.ident.clone()),
            None => None,
        })
        .collect();

    let convert_params: Vec<_> = args
        .iter()
        .filter_map(|arg| match arg {
            Some(ident) => {
                let ident = ident.ident.clone();
                Some(quote! { let #ident = ocaml::FromValue::from_value(unsafe { ocaml::Value::new(#ident) }); })
            }
            None => None,
        })
        .collect();

    if ocaml_args.is_empty() {
        ocaml_args.push(quote! { _: ocaml::Raw});
    }

    let body = &item_fn.block;

    let inner = if returns {
        quote! {
            #[inline(always)]
            #constness #unsafety fn inner(#gc_name: &mut ocaml::Runtime, #(#rust_args),*) -> #rust_return_type {
                #use_gc
                #body
            }
        }
    } else {
        quote! {
            #[inline(always)]
            #constness #unsafety fn inner(#gc_name: &mut ocaml::Runtime, #(#rust_args),*)  {
                #use_gc
                #body
            }
        }
    };

    let where_clause = &item_fn.sig.generics.where_clause;
    let attr: Vec<_> = item_fn.attrs.iter().collect();

    let gen = quote! {
        #[no_mangle]
        #(
            #attr
        )*
        pub #constness #unsafety extern "C" fn #name(#(#ocaml_args),*) -> ocaml::Raw #where_clause {
            #inner

            ocaml::body!(#gc_name: {
                #(#convert_params);*
                let res = inner(#gc_name, #param_names);
                #[allow(unused_unsafe)]
                let mut gc_ = unsafe { ocaml::Runtime::recover_handle() };
                unsafe { ocaml::IntoValue::into_value(res, &gc_).raw() }
            })
        }
    };

    if ocaml_args.len() > 5 {
        let bytecode = {
            let mut bc = item_fn.clone();
            bc.sig.ident = syn::Ident::new(&format!("{}_bytecode", name), name.span());
            ocaml_bytecode_func_impl(bc, gc_name, use_gc, Some(name))
        };

        let r = quote! {
            #gen

            #bytecode
        };
        return r.into();
    }

    gen.into()
}

/// `native_func` is used export Rust functions to OCaml, it has much lower overhead than `func`
/// and expects all arguments and return type to to be `Value`.
///
/// - Wraps the function body using `ocaml::body`
/// - Allows for an optional ident argument specifying the name of the `gc` handle parameter
#[proc_macro_attribute]
pub fn ocaml_native_func(attribute: TokenStream, item: TokenStream) -> TokenStream {
    let mut item_fn: syn::ItemFn = syn::parse(item).unwrap();
    check_func(&mut item_fn);

    let name = &item_fn.sig.ident;
    let unsafety = &item_fn.sig.unsafety;
    let constness = &item_fn.sig.constness;

    let mut gc_name = syn::Ident::new("gc", name.span());
    let mut use_gc = quote!({let _ = &#gc_name;});
    if let Ok(ident) = syn::parse::<syn::Ident>(attribute) {
        gc_name = ident;
        use_gc = quote!();
    }

    let where_clause = &item_fn.sig.generics.where_clause;
    let attr: Vec<_> = item_fn.attrs.iter().collect();

    let rust_args = &item_fn.sig.inputs;

    let args: Vec<_> = item_fn
        .sig
        .inputs
        .iter()
        .map(|arg| match arg {
            syn::FnArg::Receiver(_) => panic!("OCaml functions cannot take a self argument"),
            syn::FnArg::Typed(t) => match t.pat.as_ref() {
                syn::Pat::Ident(ident) => Some(ident),
                _ => None,
            },
        })
        .collect();

    let mut ocaml_args: Vec<_> = args
        .iter()
        .map(|t| match t {
            Some(ident) => quote! { #ident: ocaml::Raw },
            None => quote! { _: ocaml::Raw },
        })
        .collect();

    if ocaml_args.is_empty() {
        ocaml_args.push(quote! { _: ocaml::Raw});
    }

    let body = &item_fn.block;

    let (_, rust_return_type) = match &item_fn.sig.output {
        syn::ReturnType::Default => (false, None),
        syn::ReturnType::Type(_, _t) => (true, Some(quote! {ocaml::Raw})),
    };

    let gen = quote! {
        #[no_mangle]
        #(
            #attr
        )*
        pub #constness #unsafety extern "C" fn #name (#rust_args) -> #rust_return_type #where_clause {
            let r = ocaml::body!(#gc_name: {
                #use_gc
                #body
            });
            r.raw()
        }
    };
    gen.into()
}

/// `bytecode_func` is used export Rust functions to OCaml, performing the necessary wrapping/unwrapping
/// automatically.
///
/// Since this is automatically applied to `func` functions, this is primarily be used when working with
/// unboxed functions, or `native_func`s directly. `ocaml::body` is not applied since this is
/// typically used to call the native function, which is wrapped with `ocaml::body` or performs the
/// equivalent work to register values with the garbage collector
///
/// - Automatic type conversion for arguments/return value
/// - Allows for an optional ident argument specifying the name of the `gc` handle parameter
#[proc_macro_attribute]
pub fn ocaml_bytecode_func(attribute: TokenStream, item: TokenStream) -> TokenStream {
    let item_fn: syn::ItemFn = syn::parse(item).unwrap();
    let mut gc_name = syn::Ident::new("gc", item_fn.sig.ident.span());
    let mut use_gc = quote!({let _ = &#gc_name;});
    if let Ok(ident) = syn::parse::<syn::Ident>(attribute) {
        gc_name = ident;
        use_gc = quote!();
    }
    ocaml_bytecode_func_impl(item_fn, gc_name, use_gc, None).into()
}

fn ocaml_bytecode_func_impl(
    mut item_fn: syn::ItemFn,
    gc_name: syn::Ident,
    use_gc: impl quote::ToTokens,
    original: Option<&proc_macro2::Ident>,
) -> proc_macro2::TokenStream {
    check_func(&mut item_fn);

    let name = &item_fn.sig.ident;
    let unsafety = &item_fn.sig.unsafety;
    let constness = &item_fn.sig.constness;

    let (returns, rust_return_type) = match &item_fn.sig.output {
        syn::ReturnType::Default => (false, None),
        syn::ReturnType::Type(_, t) => (true, Some(t)),
    };

    let rust_args: Vec<_> = item_fn.sig.inputs.iter().collect();

    let args: Vec<_> = item_fn
        .sig
        .inputs
        .clone()
        .into_iter()
        .map(|arg| match arg {
            syn::FnArg::Receiver(_) => panic!("OCaml functions cannot take a self argument"),
            syn::FnArg::Typed(mut t) => match t.pat.as_mut() {
                syn::Pat::Ident(ident) => {
                    ident.mutability = None;
                    Some(ident.clone())
                }
                _ => None,
            },
        })
        .collect();

    let mut ocaml_args: Vec<_> = args
        .iter()
        .map(|t| match t {
            Some(ident) => {
                quote! { #ident: ocaml::Raw }
            }
            None => quote! { _: ocaml::Raw },
        })
        .collect();

    let mut param_names: syn::punctuated::Punctuated<syn::Ident, syn::token::Comma> = args
        .iter()
        .filter_map(|arg| match arg {
            Some(ident) => Some(ident.ident.clone()),
            None => None,
        })
        .collect();

    if ocaml_args.is_empty() {
        ocaml_args.push(quote! { _unit: ocaml::Raw});
        param_names.push(syn::Ident::new("__ocaml_unit", name.span()));
    }

    let body = &item_fn.block;

    let inner = match original {
        Some(o) => {
            quote! {
                #[allow(unused)]
                let __ocaml_unit = ocaml::Value::unit();
                let inner = #o;
            }
        }
        None => {
            if returns {
                quote! {
                    #[inline(always)]
                    #constness #unsafety fn inner(#(#rust_args),*) -> #rust_return_type {
                        #[allow(unused_variables)]
                        let #gc_name = unsafe { ocaml::Runtime::recover_handle() };
                        #use_gc
                        #body
                    }
                }
            } else {
                quote! {
                    #[inline(always)]
                    #constness #unsafety fn inner(#(#rust_args),*)  {
                        #[allow(unused_variables)]
                        let #gc_name = unsafe { ocaml::Runtime::recover_handle() };
                        #use_gc
                        #body
                    }
                }
            }
        }
    };

    let where_clause = &item_fn.sig.generics.where_clause;
    let attr: Vec<_> = item_fn.attrs.iter().collect();

    let len = ocaml_args.len();

    if len > 5 {
        let convert_params: Vec<_> = args
            .iter()
            .filter_map(|arg| match arg {
                Some(ident) => Some(quote! {
                    #[allow(clippy::not_unsafe_ptr_arg_deref)]
                    let #ident = ocaml::FromValue::from_value(unsafe {
                        core::ptr::read(__ocaml_argv.add(__ocaml_arg_index as usize))
                    });
                    __ocaml_arg_index += 1 ;
                }),
                None => None,
            })
            .collect();
        quote! {
            #[no_mangle]
            #(
                #attr
            )*
            pub #constness unsafe extern "C" fn #name(__ocaml_argv: *mut ocaml::Value, __ocaml_argc: i32) -> ocaml::Raw #where_clause {
                assert!(#len <= __ocaml_argc as usize, "len: {}, argc: {}", #len, __ocaml_argc);

                let #gc_name = unsafe { ocaml::Runtime::recover_handle() };

                #inner

                let mut __ocaml_arg_index = 0;
                #(#convert_params);*
                let res = inner(#param_names);
                ocaml::IntoValue::into_value(res, &#gc_name).raw()
            }
        }
    } else {
        let convert_params: Vec<_> = args
            .iter()
            .filter_map(|arg| match arg {
                Some(ident) => {
                    let ident = ident.ident.clone();
                    Some(quote! { let #ident = ocaml::FromValue::from_value(unsafe { ocaml::Value::new(#ident) }); })
                }
                None => None,
            })
            .collect();
        quote! {
            #[no_mangle]
            #(
                #attr
            )*
            pub #constness #unsafety extern "C" fn #name(#(#ocaml_args),*) -> ocaml::Raw #where_clause {
                #[allow(unused_variables)]
                let #gc_name = unsafe { ocaml::Runtime::recover_handle() };

                #inner

                #(#convert_params);*
                let res = inner(#param_names);
                ocaml::IntoValue::into_value(res, &#gc_name).raw()
            }
        }
    }
}

synstructure::decl_derive!([IntoValue, attributes(ocaml)] => derive::intovalue_derive);
synstructure::decl_derive!([FromValue, attributes(ocaml)] => derive::fromvalue_derive);
