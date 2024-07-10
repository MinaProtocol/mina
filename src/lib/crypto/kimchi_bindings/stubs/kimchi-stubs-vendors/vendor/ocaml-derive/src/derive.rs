use quote::quote;

#[derive(Default)]
struct Attrs {
    unboxed: bool,
    floats: bool,
}

fn is_ocaml(path: &syn::Path) -> bool {
    path.segments.len() == 1
        && path
            .segments
            .iter()
            .next()
            .map_or(false, |segment| segment.ident == "ocaml")
}

fn variant_attrs(attrs: &[syn::Attribute]) -> Attrs {
    attrs
        .iter()
        .find(|attr| is_ocaml(&attr.path))
        .map_or(Default::default(), |attr| {
            if let Ok(syn::Meta::List(ref list)) = attr.parse_meta() {
                list.nested
                    .iter()
                    .fold(Default::default(), |mut acc, meta| match meta {
                        syn::NestedMeta::Meta(syn::Meta::Path(ref path)) => {
                            if let Some(ident) = path.get_ident() {
                                if ident == "unboxed" {
                                    if acc.floats {
                                        panic!("in ocaml attrs a variant cannot be both float array and unboxed")
                                    }
                                    acc.unboxed = true;
                                    acc
                                } else if ident == "floats_array" {
                                    if acc.unboxed {
                                        panic!("in ocaml attrs a variant cannot be both float array and unboxed")
                                    }
                                    acc.floats = true;
                                    acc
                                } else {
                                    panic!("unexpected ocaml attribute parameter {}", ident)
                                }
                            } else {
                                acc
                            }
                        }
                     _ => panic!("unexpected ocaml attribute parameter"),
                    })
            } else {
                panic!("ocaml attribute must take a list of valid attributes in parentheses")
            }
        })
}

pub fn intovalue_derive(mut s: synstructure::Structure) -> proc_macro::TokenStream {
    let mut unit_tag = 0u8;
    let mut non_unit_tag = 0u8;
    let is_record_like = s.variants().len() == 1;
    let body = s.variants_mut().to_vec().into_iter().map(|mut variant| {
        let arity = variant.bindings().len();
        for b in variant.bindings_mut() {
            b.style = synstructure::BindStyle::Move;
        }
        let tag_ref = if arity > 0 {
            &mut non_unit_tag
        } else {
            &mut unit_tag
        };
        let tag = *tag_ref;
        *tag_ref += 1;
        let attrs = variant_attrs(&variant.ast().attrs);
        if (attrs.floats || attrs.unboxed) && !is_record_like {
            panic!("ocaml cannot derive unboxed or float arrays for enums")
        }
        if arity == 0 {
            let init = quote!(value = unsafe { ocaml::Value::int(#tag as ocaml::Int)});
            variant.fold(init, |_, _| quote!())
        } else if attrs.floats {
            let mut idx = 0usize;
            let init = quote!(
                value = unsafe { ocaml::Value::alloc(#arity, ocaml::Tag::DOUBLE_ARRAY) };
            );
            variant.fold(init, |acc, b| {
                let i = idx;
                idx += 1;
                quote!(#acc; ocaml::array::set_double(value, #i, *#b as f64).unwrap();)
            })
        } else if attrs.unboxed {
            if variant.bindings().len() > 1 {
                panic!("ocaml cannot unboxed record with multiple fields")
            }
            variant.each(|field| quote!(#field.into_value(gc)))
        } else {
            let mut idx = 0usize;
            let ghost = (0..arity)
                .map(|idx| quote!(unsafe { value.store_field(gc, #idx, ocaml::Value::unit()) }));
            let init = quote!(
                value = unsafe { ocaml::Value::alloc(#arity, ocaml::Tag(#tag)) };
                #(#ghost);*;
            );
            variant.fold(init, |acc, b| {
                let i = idx;
                idx += 1;
                quote!(#acc unsafe { value.store_field(gc, #i, #b)};)
            })
        }
    });

    s.gen_impl(quote! {
        gen unsafe impl ocaml::IntoValue for @Self {
            fn into_value(self, gc: &ocaml::Runtime) -> ocaml::Value {
                let mut value = ocaml::Value::unit();
                match self {
                    #(#body),*
                }
                value
            }
        }
    })
    .into()
}

pub fn fromvalue_derive(s: synstructure::Structure) -> proc_macro::TokenStream {
    let mut unit_tag = 0u8;
    let mut non_unit_tag = 0u8;
    let is_record_like = s.variants().len() == 1;
    let attrs = if is_record_like {
        variant_attrs(s.variants()[0].ast().attrs)
    } else {
        Attrs::default()
    };
    let body = s.variants().iter().map(|variant| {
        let arity = variant.bindings().len();
        let tag_ref = if arity > 0 {
            &mut non_unit_tag
        } else {
            &mut unit_tag
        };
        let attrs = variant_attrs(&variant.ast().attrs);
        if (attrs.floats || attrs.unboxed) && !is_record_like {
            panic!("ocaml cannot derive unboxed records or float arrays for enums")
        }
        let tag = *tag_ref;
        *tag_ref += 1;
        let is_block = arity != 0;
        if attrs.unboxed {
            if arity > 1 {
                panic!("ocaml cannot derive unboxed records with several fields")
            }
            variant.construct(|_, _| quote!(ocaml::FromValue::from_value(value)))
        } else {
            let construct = variant.construct(|field, idx| {
                if attrs.floats {
                    let ty = &field.ty;
                    quote!(ocaml::array::get_double(value, #idx).unwrap() as #ty)
                } else {
                    quote!(ocaml::FromValue::from_value(value.field(#idx)))
                }
            });
            quote!((#is_block, #tag) => {
                #construct
            }
            )
        }
    });
    if attrs.unboxed {
        s.gen_impl(quote! {
            gen unsafe impl<'from_value_lifetime> ocaml::FromValue<'from_value_lifetime> for @Self {
                fn from_value(value: ocaml::Value) -> Self {
                    #(#body),*
                }
            }
        })
        .into()
    } else {
        let tag = if !attrs.floats {
            quote!({ unsafe { value.tag() } })
        } else {
            quote!({
                if unsafe { value.tag() } != ocaml::Tag::DOUBLE_ARRAY {
                    panic!("ocaml ffi: trying to convert a value which is not a double array to an unboxed record")
                };
                0
            })
        };
        s.gen_impl(quote! {
            gen unsafe impl<'from_value_lifetime> ocaml::FromValue<'from_value_lifetime> for @Self {
                fn from_value(value: ocaml::Value) -> Self {
                    unsafe {
                        let is_block = value.is_block();
                        let tag = if !is_block { value.int_val() as u8 } else { #tag.0 };
                        match (is_block, tag) {
                            #(#body),*
                            _ => panic!("ocaml ffi: received unknown variant while trying to convert ocaml structure/enum to rust"),
                        }
                    }
                }
            }
        }).into()
    }
}
