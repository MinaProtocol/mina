#![deny(missing_docs)]

//! **This crate is not meant to be imported directly by users**.
//! You should import [ocaml-gen](https://crates.io/crates/ocaml-gen) instead.
//!
//! ocaml-gen-derive adds a number of derives to make ocaml-gen easier to use.
//! Refer to the [ocaml-gen](https://o1-labs.github.io/ocaml-gen/ocaml_gen/index.html) documentation.

extern crate proc_macro;
use convert_case::{Case, Casing};
use proc_macro::TokenStream;
use proc_macro2::{Ident, Span};
use quote::quote;
use syn::{
    punctuated::Punctuated, Fields, FnArg, GenericParam, PredicateType, ReturnType, TraitBound,
    TraitBoundModifier, Type, TypeParamBound, TypePath, WherePredicate,
};

/// A macro to create OCaml bindings for a function that uses [`#[ocaml::func]`](https://docs.rs/ocaml/latest/ocaml/attr.func.html)
///
/// Note that this macro must be placed first (before `#[ocaml::func]`).
/// For example:
///
/// ```
/// #[ocaml_gen::func]
/// #[ocaml::func]
/// pub fn something(arg1: String) {
///   //...
/// }
/// ```
///
#[proc_macro_attribute]
pub fn func(_attribute: TokenStream, item: TokenStream) -> TokenStream {
    let item_fn: syn::ItemFn = syn::parse(item).expect("couldn't parse item");

    let rust_name = &item_fn.sig.ident;
    let inputs = &item_fn.sig.inputs;
    let output = &item_fn.sig.output;

    let ocaml_name = rust_ident_to_ocaml(&rust_name.to_string());

    let inputs: Vec<_> = inputs
        .into_iter()
        .filter_map(|i| match i {
            FnArg::Typed(t) => Some(&t.ty),
            FnArg::Receiver(_) => None,
        })
        .collect();

    let return_value = match output {
        ReturnType::Default => quote! { "unit".to_string() },
        ReturnType::Type(_, t) => quote! {
            <#t as ::ocaml_gen::OCamlDesc>::ocaml_desc(env, &[])
        },
    };

    let rust_name_str = rust_name.to_string();

    let fn_name = Ident::new(&format!("{rust_name}_to_ocaml"), Span::call_site());

    let new_fn = quote! {
        pub fn #fn_name(env: &::ocaml_gen::Env, rename: Option<&'static str>) -> String {
            // function name
            let ocaml_name = rename.unwrap_or(#ocaml_name);

            // arguments
            let mut args: Vec<String> = vec![];
            #(
                args.push(
                    <#inputs as ::ocaml_gen::OCamlDesc>::ocaml_desc(env, &[])
                );
            );*
            let inputs = if args.len() == 0 {
                "unit".to_string()
            } else {
                args.join(" -> ")
            };

            // return value
            let return_value = #return_value;

            if args.len() <= 5 {
                format!(
                    "external {} : {} -> {} = \"{}\"",
                    ocaml_name, inputs, return_value, #rust_name_str
                )
            }
            // !! This is not the best way to handle this case. This will break
            // if ocaml-rs changes its code generator.
            else {
                format!(
                    "external {} : {} -> {} = \"{}_bytecode\" \"{}\"",
                    ocaml_name, inputs, return_value, #rust_name_str, #rust_name_str
                )
            }
            // return the binding
        }
    };

    let gen = quote! {
        // don't forget to generate code that also contains the old function :)
        #item_fn
        #new_fn
    };

    gen.into()
}

//
// Enum
//

/// The Enum derive macro.
/// It generates implementations of `ToOCaml` and `OCamlBinding` on an enum type.
/// The type must implement [`ocaml::IntoValue`](https://docs.rs/ocaml/latest/ocaml/trait.IntoValue.html)
/// and [`ocaml::FromValue`](https://docs.rs/ocaml/latest/ocaml/trait.FromValue.html)
/// For example:
///
/// ```
/// use ocaml_gen::Enum;
///
/// #[Enum]
/// enum MyType {
///   // ...
/// }
/// ```
///
#[proc_macro_derive(Enum)]
pub fn derive_ocaml_enum(item: TokenStream) -> TokenStream {
    let item_enum: syn::ItemEnum = syn::parse(item).expect("only enum are supported with Enum");

    //
    // ocaml_desc
    //

    let generics_ident: Vec<_> = item_enum
        .generics
        .params
        .iter()
        .filter_map(|g| match g {
            GenericParam::Type(t) => Some(&t.ident),
            _ => None,
        })
        .collect();

    let name_str = item_enum.ident.to_string();

    let ocaml_desc = quote! {
        fn ocaml_desc(env: &::ocaml_gen::Env, generics: &[&str]) -> String {
            // get type parameters
            let mut generics_ocaml: Vec<String> = vec![];
            #(
                generics_ocaml.push(
                    <#generics_ident as ::ocaml_gen::OCamlDesc>::ocaml_desc(env, generics)
                );
            );*

            // get name
            let type_id = <Self as ::ocaml_gen::OCamlDesc>::unique_id();
            let (name, aliased) = env.get_type(type_id, #name_str);

            // return the type description in OCaml
            if generics_ocaml.is_empty() || aliased {
                name.to_string()
            } else {
                format!("({}) {}", generics_ocaml.join(", "), name)
            }
        }
    };

    //
    // unique_id
    //

    let unique_id = quote! {
        fn unique_id() -> u128 {
            ::ocaml_gen::const_random!(u128)
        }
    };

    //
    // ocaml_binding
    //

    let generics_str: Vec<String> = item_enum
        .generics
        .params
        .iter()
        .filter_map(|g| match g {
            GenericParam::Type(t) => Some(t.ident.to_string().to_case(Case::Snake)),
            _ => None,
        })
        .collect();

    let body = {
        // we want to resolve types at runtime (to do relocation/renaming)
        // to do that, the macro builds a list of types that doesn't need to be resolved (generic types), as well as a list of types to resolve
        // at runtime, both list are consumed to generate the OCaml binding

        // list of variants
        let mut variants: Vec<String> = vec![];
        // list of types associated to each variant. It is punctured:
        // an item can appear as "#" to indicate that it needs to be resolved at run-time
        let mut punctured_types: Vec<Vec<String>> = vec![];
        // list of types that will need to be resolved at run-time
        let mut fields_to_call = vec![];

        // go through each variant to build these lists
        for variant in &item_enum.variants {
            let name = &variant.ident;
            variants.push(name.to_string());
            let mut types = vec![];
            match &variant.fields {
                Fields::Named(_f) => panic!("named types not implemented"),
                Fields::Unnamed(fields) => {
                    for field in &fields.unnamed {
                        if let Some(ty) = is_generic(&generics_str, &field.ty) {
                            types.push(format!("'{}", ty.to_case(Case::Snake)));
                        } else {
                            types.push("#".to_string());
                            fields_to_call.push(&field.ty);
                        }
                    }
                }
                Fields::Unit => (),
            };
            punctured_types.push(types);
        }
        fields_to_call.reverse();

        quote! {
            let mut generics_ocaml: Vec<String> = vec![];
            let variants: Vec<&str> = vec![
                #(#variants),*
            ];
            let punctured_types: Vec<Vec<&str>> = vec![
                #(
                    vec![
                        #(#punctured_types),*
                    ]
                ),*
            ];

            let mut missing_types: Vec<String> = vec![];
            #(
                missing_types.push(
                    <#fields_to_call as ::ocaml_gen::OCamlDesc>::ocaml_desc(env, &global_generics)
                );
            );*

            for (name, types) in variants.into_iter().zip(punctured_types) {
                let mut fields = vec![];
                for ty in types {
                    if ty != "#" {
                        fields.push(ty.to_string());
                    } else {
                        let ty = missing_types
                            .pop()
                            .expect("number of types to call should match number of missing types");
                        fields.push(ty);
                    }
                }

                // example: type 'a t = Infinity | Finite of 'a
                let tag = if fields.is_empty() {
                    name.to_string()
                } else {
                    format!("{} of {}", name, fields.join(" * "))
                };
                generics_ocaml.push(tag);
            }
            format!("{}", generics_ocaml.join(" | "))
        }
    };

    let ocaml_name = rust_ident_to_ocaml(&name_str);

    let ocaml_binding = quote! {
        fn ocaml_binding(
            env: &mut ::ocaml_gen::Env,
            rename: Option<&'static str>,
            new_type: bool,
        ) -> String {
            // register the new type
            if new_type {
                let ty_name = rename.unwrap_or(#ocaml_name);
                let ty_id = <Self as ::ocaml_gen::OCamlDesc>::unique_id();
                env.new_type(ty_id, ty_name);
            }

            let global_generics: Vec<&str> = vec![#(#generics_str),*];
            let generics_ocaml = {
                #body
            };

            let name = <Self as ::ocaml_gen::OCamlDesc>::ocaml_desc(env, &global_generics);

            if new_type {
                format!("type nonrec {} = {}", name, generics_ocaml)
            } else {
                format!("type nonrec {} = {}", rename.expect("type alias must have a name"), name)
            }
        }
    };

    //
    // Implementations
    //

    let (impl_generics, ty_generics, _where_clause) = item_enum.generics.split_for_impl();

    // add OCamlDesc bounds to the generic types
    let mut extended_generics = item_enum.generics.clone();
    extended_generics.make_where_clause();
    let mut extended_where_clause = extended_generics.where_clause.unwrap();
    let path: syn::Path = syn::parse_str("::ocaml_gen::OCamlDesc").unwrap();
    let impl_ocaml_desc = TraitBound {
        paren_token: None,
        modifier: TraitBoundModifier::None,
        lifetimes: None,
        path,
    };
    for generic in &item_enum.generics.params {
        if let GenericParam::Type(t) = generic {
            let mut bounds = Punctuated::<TypeParamBound, syn::token::Add>::new();
            bounds.push(TypeParamBound::Trait(impl_ocaml_desc.clone()));

            let path: syn::Path = syn::parse_str(&t.ident.to_string()).unwrap();

            let bounded_ty = Type::Path(TypePath { qself: None, path });

            extended_where_clause
                .predicates
                .push(WherePredicate::Type(PredicateType {
                    lifetimes: None,
                    bounded_ty,
                    colon_token: syn::token::Colon {
                        spans: [Span::call_site()],
                    },
                    bounds,
                }));
        };
    }

    // generate implementations for OCamlDesc and OCamlBinding
    let name = item_enum.ident;
    let gen = quote! {
        impl #impl_generics ::ocaml_gen::OCamlDesc for #name #ty_generics #extended_where_clause {
            #ocaml_desc
            #unique_id
        }

        impl #impl_generics ::ocaml_gen::OCamlBinding for #name #ty_generics  #extended_where_clause {
            #ocaml_binding
        }
    };
    gen.into()
}

//
// Struct
//

/// The Struct derive macro.
/// It generates implementations of `ToOCaml` and `OCamlBinding` on a struct.
/// The type must implement [`ocaml::IntoValue`](https://docs.rs/ocaml/latest/ocaml/trait.IntoValue.html)
/// and [`ocaml::FromValue`](https://docs.rs/ocaml/latest/ocaml/trait.FromValue.html)
///
/// For example:
///
/// ```
/// #[ocaml_gen::Struct]
/// struct MyType {
///   // ...
/// }
/// ```
///
#[proc_macro_derive(Struct)]
pub fn derive_ocaml_gen(item: TokenStream) -> TokenStream {
    let item_struct: syn::ItemStruct =
        syn::parse(item).expect("only structs are supported with Struct");
    let name = &item_struct.ident;
    let generics = &item_struct.generics.params;
    let fields = &item_struct.fields;

    //
    // ocaml_desc
    //

    let generics_ident: Vec<_> = generics
        .iter()
        .filter_map(|g| match g {
            GenericParam::Type(t) => Some(&t.ident),
            _ => None,
        })
        .collect();

    let name_str = name.to_string();

    let ocaml_desc = quote! {
        fn ocaml_desc(env: &::ocaml_gen::Env, generics: &[&str]) -> String {
            // get type parameters
            let mut generics_ocaml: Vec<String> = vec![];
            #(
                generics_ocaml.push(
                    <#generics_ident as ::ocaml_gen::OCamlDesc>::ocaml_desc(env, generics)
                );
            );*

            // get name
            let type_id = <Self as ::ocaml_gen::OCamlDesc>::unique_id();
            let (name, aliased) = env.get_type(type_id, #name_str);

            // return the type description in OCaml
            if generics_ocaml.is_empty() || aliased {
                name.to_string()
            } else {
                format!("({}) {}", generics_ocaml.join(", "), name)
            }
        }
    };

    //
    // unique_id
    //

    let unique_id = quote! {
        fn unique_id() -> u128 {
            ::ocaml_gen::const_random!(u128)
        }
    };

    //
    // ocaml_binding
    //

    let generics_str: Vec<String> = generics
        .iter()
        .filter_map(|g| match g {
            GenericParam::Type(t) => Some(t.ident.to_string().to_case(Case::Snake)),
            _ => None,
        })
        .collect();

    let body = match fields {
        Fields::Named(fields) => {
            let mut punctured_generics_name: Vec<String> = vec![];
            let mut punctured_generics_type: Vec<String> = vec![];
            let mut fields_to_call = vec![];
            for field in &fields.named {
                let name = field.ident.as_ref().expect("a named field has an ident");
                punctured_generics_name.push(name.to_string());
                if let Some(ty) = is_generic(&generics_str, &field.ty) {
                    punctured_generics_type.push(format!("'{}", ty.to_case(Case::Snake)));
                } else {
                    punctured_generics_type.push("#".to_string());
                    fields_to_call.push(&field.ty);
                }
            }
            fields_to_call.reverse();

            quote! {
                let mut generics_ocaml: Vec<String> = vec![];
                let punctured_generics_name: Vec<&str> = vec![
                    #(#punctured_generics_name),*
                ];
                let punctured_generics_type: Vec<&str> = vec![
                    #(#punctured_generics_type),*
                ];

                let mut missing_types: Vec<String> = vec![];
                #(
                    missing_types.push(
                        <#fields_to_call as ::ocaml_gen::OCamlDesc>::ocaml_desc(env, &global_generics)
                    );
                );*

                for (name, ty) in punctured_generics_name.into_iter().zip(punctured_generics_type) {
                    if ty != "#" {
                        generics_ocaml.push(
                            format!("{}: {}", name, ty.to_string())
                        );
                    } else {
                        let ty = missing_types
                            .pop()
                            .expect("number of types to call should match number of missing types");
                        generics_ocaml.push(
                            format!("{}: {}", name, ty)
                        );
                    }
                }

                // See https://v2.ocaml.org/manual/attributes.html for boxing/unboxing
                if generics_ocaml.len() == 1 {
                    // Tell the OCaml compiler to not unbox records of size 1
                    format!("{{ {} }} [@@boxed]", generics_ocaml[0])
                } else {
                    // OCaml does not unbox records with 2+ fields, so the annotation is unnecessary
                    format!("{{ {} }}", generics_ocaml.join("; "))
                }

            }
        }
        Fields::Unnamed(fields) => {
            let mut punctured_generics: Vec<String> = vec![];
            let mut fields_to_call = vec![];
            for field in &fields.unnamed {
                if let Some(ident) = is_generic(&generics_str, &field.ty) {
                    punctured_generics.push(format!("'{}", ident.to_case(Case::Snake)));
                } else {
                    punctured_generics.push("#".to_string());
                    fields_to_call.push(&field.ty);
                }
            }
            fields_to_call.reverse();

            quote! {
                let mut generics_ocaml: Vec<String> = vec![];

                let punctured_generics: Vec<&str> = vec![
                    #(#punctured_generics),*
                ];

                let mut missing_types: Vec<String> = vec![];
                #(
                    missing_types.push(<#fields_to_call as ::ocaml_gen::OCamlDesc>::ocaml_desc(env, &global_generics));
                );*

                for ty in punctured_generics {
                    if ty != "#" {
                        generics_ocaml.push(ty.to_string());
                    } else {
                        let ident = missing_types
                            .pop()
                            .expect("number of types to call should match number of missing types");
                        generics_ocaml.push(ident);
                    }
                }

                // when there's a single element,
                // this will produce something like this:
                //
                // ```
                // type ('field) scalar_challenge =  { inner: 'field } [@@boxed]
                // ```
                if generics_ocaml.len() == 1 {
                    format!("{{ inner: {} }} [@@boxed]", generics_ocaml[0])
                } else {
                    generics_ocaml.join(" * ")
                }
            }
        }
        Fields::Unit => panic!("only named, and unnamed field supported"),
    };

    let ocaml_name = rust_ident_to_ocaml(&name_str);

    let ocaml_binding = quote! {
        fn ocaml_binding(
            env: &mut ::ocaml_gen::Env,
            rename: Option<&'static str>,
            new_type: bool,
        ) -> String {
            // register the new type
            let ty_id = <Self as ::ocaml_gen::OCamlDesc>::unique_id();

            if new_type {
                let ty_name = rename.unwrap_or(#ocaml_name);
                env.new_type(ty_id, ty_name);
            }

            let global_generics: Vec<&str> = vec![#(#generics_str),*];
            let generics_ocaml = {
                #body
            };

            let name = <Self as ::ocaml_gen::OCamlDesc>::ocaml_desc(env, &global_generics);

            if new_type {
                format!("type nonrec {} = {}", name, generics_ocaml)
            } else {
                // add the alias
                let ty_name = rename.expect("bug in ocaml-gen: rename should be Some");
                env.add_alias(ty_id, ty_name);

                format!("type nonrec {} = {}", ty_name, name)
            }
        }
    };

    //
    // Implementations
    //

    let (impl_generics, ty_generics, _where_clause) = item_struct.generics.split_for_impl();

    // add OCamlDesc bounds to the generic types
    let mut extended_generics = item_struct.generics.clone();
    extended_generics.make_where_clause();
    let mut extended_where_clause = extended_generics.where_clause.unwrap();
    let path: syn::Path = syn::parse_str("::ocaml_gen::OCamlDesc").unwrap();
    let impl_ocaml_desc = TraitBound {
        paren_token: None,
        modifier: TraitBoundModifier::None,
        lifetimes: None,
        path,
    };
    for generic in generics {
        if let GenericParam::Type(t) = generic {
            let mut bounds = Punctuated::<TypeParamBound, syn::token::Add>::new();
            bounds.push(TypeParamBound::Trait(impl_ocaml_desc.clone()));

            let path: syn::Path = syn::parse_str(&t.ident.to_string()).unwrap();

            let bounded_ty = Type::Path(TypePath { qself: None, path });

            extended_where_clause
                .predicates
                .push(WherePredicate::Type(PredicateType {
                    lifetimes: None,
                    bounded_ty,
                    colon_token: syn::token::Colon {
                        spans: [Span::call_site()],
                    },
                    bounds,
                }));
        };
    }

    // generate implementations for OCamlDesc and OCamlBinding
    let gen = quote! {
        impl #impl_generics ::ocaml_gen::OCamlDesc for #name #ty_generics #extended_where_clause {
            #ocaml_desc
            #unique_id
        }

        impl #impl_generics ::ocaml_gen::OCamlBinding for #name #ty_generics  #extended_where_clause {
            #ocaml_binding
        }
    };
    gen.into()
}

//
// almost same code for custom types
//

/// Derives implementations for `OCamlDesc` and `OCamlBinding` on a custom type
/// For example:
///
/// ```
/// use ocaml_gen::CustomType;
///
/// #[CustomType]
/// struct MyCustomType {
///   // ...
/// }
/// ```
///
#[proc_macro_derive(CustomType)]
pub fn derive_ocaml_custom(item: TokenStream) -> TokenStream {
    let item_struct: syn::ItemStruct =
        syn::parse(item).expect("only structs are supported at the moment");
    let name = &item_struct.ident;

    //
    // ocaml_desc
    //

    let name_str = name.to_string();

    let ocaml_desc = quote! {
        fn ocaml_desc(env: &::ocaml_gen::Env, _generics: &[&str]) -> String {
            let type_id = <Self as ::ocaml_gen::OCamlDesc>::unique_id();
            env.get_type(type_id, #name_str).0
        }
    };

    //
    // unique_id
    //

    let unique_id = quote! {
        fn unique_id() -> u128 {
            ::ocaml_gen::const_random!(u128)
        }
    };

    //
    // ocaml_binding
    //

    let ocaml_name = rust_ident_to_ocaml(&name_str);

    let ocaml_binding = quote! {
        fn ocaml_binding(
            env: &mut ::ocaml_gen::Env,
            rename: Option<&'static str>,
            new_type: bool,
        ) -> String {
            // register the new type
            let ty_id = <Self as ::ocaml_gen::OCamlDesc>::unique_id();

            if new_type {
                let ty_name = rename.unwrap_or(#ocaml_name);
                env.new_type(ty_id, ty_name);
            }

            let name = <Self as ::ocaml_gen::OCamlDesc>::ocaml_desc(env, &[]);

            if new_type {
                format!("type nonrec {}", name)
            } else {
                // add the alias
                let ty_name = rename.expect("bug in ocaml-gen: rename should be Some");
                env.add_alias(ty_id, ty_name);

                format!("type nonrec {} = {}", ty_name, name)
            }
        }
    };

    //
    // Implementations
    //

    let (impl_generics, ty_generics, where_clause) = item_struct.generics.split_for_impl();

    // generate implementations for OCamlDesc and OCamlBinding
    let gen = quote! {
        impl #impl_generics ::ocaml_gen::OCamlDesc for #name #ty_generics #where_clause {
            #ocaml_desc
            #unique_id
        }

        impl #impl_generics ::ocaml_gen::OCamlBinding for #name #ty_generics  #where_clause {
            #ocaml_binding
        }
    };

    gen.into()
}

//
// helpers
//

/// OCaml identifiers are `snake_case`, whereas Rust identifiers are CamelCase
fn rust_ident_to_ocaml(ident: &str) -> String {
    ident.to_case(Case::Snake)
}

/// return true if the type passed is a generic
fn is_generic(generics: &[String], ty: &Type) -> Option<String> {
    if let Type::Path(p) = ty {
        if let Some(ident) = p.path.get_ident() {
            let ident = ident.to_string();
            if generics.contains(&ident) {
                return Some(ident);
            }
        }
    }
    None
}
