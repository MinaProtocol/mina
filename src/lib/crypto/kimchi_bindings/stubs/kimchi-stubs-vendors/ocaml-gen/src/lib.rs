#![deny(missing_docs)]
#![doc = include_str!("../README.md")]

extern crate ocaml_gen_derive;
use std::collections::{hash_map::Entry, HashMap};

pub use const_random::const_random;
pub use ocaml_gen_derive::*;
pub use paste::paste;

pub mod conv;

//
// User-friendly prologue
//

/// To use the library, you can simply import the prelude as in:
///
/// ```
/// use ocaml_gen::prelude::*;
/// ```
///
pub mod prelude {
    pub use super::{decl_fake_generic, decl_func, decl_module, decl_type, decl_type_alias, Env};
}

//
// Structs
//

/// The environment at some point in time during the declaration of OCaml bindings.
/// It ensures that types cannot be declared twice, and that types that are
/// renamed and/or relocated into module are referenced correctly.
#[derive(Debug)]
pub struct Env {
    /// every type (their path and their name) is stored here at declaration
    locations: HashMap<u128, (Vec<&'static str>, &'static str)>,

    /// the current path we're in (e.g. `ModA.ModB`)
    current_module: Vec<&'static str>,

    /// list of aliases. When entering a module, the vec is extended.
    /// When exiting a module, the vec is poped.
    /// This way, aliases are kept within their own modules.
    aliases: Vec<HashMap<u128, &'static str>>,
}

impl Drop for Env {
    /// This makes sure that we close our OCaml modules (with the keyword `end`).
    fn drop(&mut self) {
        assert!(self.current_module.is_empty(), "you must call .root() on the environment to finalize the generation. You are currently still nested: {:?}", self.current_module);
    }
}

impl Default for Env {
    fn default() -> Self {
        Self::new()
    }
}

impl Env {
    /// Creates a new environment.
    #[must_use]
    pub fn new() -> Self {
        Self {
            locations: HashMap::new(),
            current_module: Vec::new(),
            aliases: vec![HashMap::new()],
        }
    }

    /// Declares a new type. If the type was already declared, this will panic.
    ///
    /// # Panics
    /// The function will panic if the type was already declared.
    pub fn new_type(&mut self, ty: u128, name: &'static str) {
        match self.locations.entry(ty) {
            Entry::Occupied(_) => panic!("ocaml-gen: cannot re-declare the same type twice"),
            Entry::Vacant(v) => v.insert((self.current_module.clone(), name)),
        };
    }

    /// Retrieves a type that was declared previously.
    /// A boolean indicates if the type is being aliased.
    ///
    /// # Panics
    /// The function will panic if the type was not declared previously.
    #[must_use]
    pub fn get_type(&self, ty: u128, name: &str) -> (String, bool) {
        // first, check if we have an alias for this type
        if let Some(alias) = self
            .aliases
            .last()
            .expect("ocaml-gen bug: bad initialization of aliases")
            .get(&ty)
        {
            return ((*alias).to_string(), true);
        }

        // otherwise, check where the type is declared
        let (type_path, type_name) = self
            .locations
            .get(&ty)
            .unwrap_or_else(|| panic!("ocaml-gen: the type {name} hasn't been declared"));

        // path resolution
        let mut current = self.current_module.clone();
        current.reverse();
        let path: Vec<&str> = type_path
            .iter()
            .skip_while(|&p| Some(*p) == current.pop())
            .copied()
            .collect();

        let name = if path.is_empty() {
            (*type_name).to_string()
        } else {
            format!("{}.{}", path.join("."), type_name)
        };

        (name, false)
    }

    /// Adds a new alias for the current scope (module).
    ///
    /// # Panics
    /// The function will panic if the alias was already declared.
    pub fn add_alias(&mut self, ty: u128, alias: &'static str) {
        let res = self
            .aliases
            .last_mut()
            .expect("bug in ocaml-gen: the Env initializer is broken")
            .insert(ty, alias);
        assert!(
            res.is_none(),
            "ocaml-gen: cannot re-declare the same alias twice"
        );
    }

    /// Create a module and enters it.
    ///
    /// # Panics
    /// This function will panic if the module was already declared,
    /// or if the module name is not following the OCaml guidelines.
    pub fn new_module(&mut self, mod_name: &'static str) -> String {
        let first_letter = mod_name
            .chars()
            .next()
            .expect("module name cannot be empty");
        assert!(
            first_letter.to_uppercase().to_string() == first_letter.to_string(),
            "ocaml-gen: OCaml module names start with an uppercase, you provided: {mod_name}"
        );

        // nest into the aliases vector
        self.aliases.push(HashMap::new());

        // create a module
        self.current_module.push(mod_name);

        format!("module {mod_name} = struct ")
    }

    /// how deeply nested are we currently? (default is 0)
    #[must_use]
    pub fn nested(&self) -> usize {
        self.current_module.len()
    }

    /// called when we exit a module
    pub fn parent(&mut self) -> String {
        // destroy any aliases
        self.aliases.pop();

        // go back up one module
        self.current_module
            .pop()
            .expect("ocaml-gen: you are already at the root");
        "end".to_string()
    }

    /// you can call this to go back to the root and finalize the generation
    pub fn root(&mut self) -> String {
        let mut res = String::new();
        for _ in &self.current_module {
            res.push_str("end\n");
        }
        res
    }
}

//
// Traits
//

/// `OCamlBinding` is the trait implemented by types to generate their OCaml bindings.
/// It is usually derived automatically via the [Struct] macro,
/// or the [`CustomType`] macro for custom types.
/// For functions, refer to the [func] macro.
pub trait OCamlBinding {
    /// will generate the OCaml bindings for a type (called root type).
    /// It takes the current environment [Env],
    /// as well as an optional name (if you wish to rename the type in OCaml).
    fn ocaml_binding(env: &mut Env, rename: Option<&'static str>, new_type: bool) -> String;
}

/// `OCamlDesc` is the trait implemented by types to facilitate generation of their OCaml bindings.
/// It is usually derived automatically via the [Struct] macro,
/// or the [`CustomType`] macro for custom types.
pub trait OCamlDesc {
    /// describes the type in OCaml, given the current environment [Env]
    /// and the list of generic type parameters of the root type
    /// (the type that makes use of this type)
    fn ocaml_desc(env: &Env, generics: &[&str]) -> String;

    /// Returns a unique ID for the type. This ID will not change if concrete type parameters are used.
    fn unique_id() -> u128;
}

//
// Func-like macros
//

/// Creates a module
#[macro_export]
macro_rules! decl_module {
    ($w:expr, $env:expr, $name:expr, $b:block) => {{
        use std::io::Write;
        write!($w, "\n{}{}\n", format_args!("{: >1$}", "", $env.nested() * 2), $env.new_module($name)).unwrap();
        $b
        write!($w, "{}{}\n\n", format_args!("{: >1$}", "", $env.nested() * 2 - 2), $env.parent()).unwrap();
    }}
}

/// Declares the binding for a given function
#[macro_export]
macro_rules! decl_func {
    ($w:expr, $env:expr, $func:ident) => {{
        use std::io::Write;
        ::ocaml_gen::paste! {
            let binding = [<$func _to_ocaml>]($env, None);
        }
        write!(
            $w,
            "{}{}\n",
            format_args!("{: >1$}", "", $env.nested() * 2),
            binding,
        )
        .unwrap();
    }};
    // rename
    ($w:expr, $env:expr, $func:ident => $new:expr) => {{
        use std::io::Write;
        ::ocaml_gen::paste! {
            let binding = [<$func _to_ocaml>]($env, Some($new));
        }
        write!(
            $w,
            "{}{}\n",
            format_args!("{: >1$}", "", $env.nested() * 2),
            binding,
        )
        .unwrap();
    }};
}

/// Declares the binding for a given type
#[macro_export]
macro_rules! decl_type {
    ($w:expr, $env:expr, $ty:ty) => {{
        use std::io::Write;
        let res = <$ty as ::ocaml_gen::OCamlBinding>::ocaml_binding($env, None, true);
        write!(
            $w,
            "{}{}\n",
            format_args!("{: >1$}", "", $env.nested() * 2),
            res,
        )
        .unwrap();
    }};
    // rename
    ($w:expr, $env:expr, $ty:ty => $new:expr) => {{
        use std::io::Write;
        let res = <$ty as ::ocaml_gen::OCamlBinding>::ocaml_binding($env, Some($new), true);
        write!(
            $w,
            "{}{}\n",
            format_args!("{: >1$}", "", $env.nested() * 2),
            res,
        )
        .unwrap();
    }};
}

/// Declares a new OCaml type that is made of other types
#[macro_export]
macro_rules! decl_type_alias {
    ($w:expr, $env:expr, $new:expr => $ty:ty) => {{
        use std::io::Write;
        let res = <$ty as ::ocaml_gen::OCamlBinding>::ocaml_binding($env, Some($new), false);
        write!(
            $w,
            "{}{}\n",
            format_args!("{: >1$}", "", $env.nested() * 2),
            res,
        )
        .unwrap();
    }};
}

/// Creates a fake generic. This is a necessary hack, at the moment, to declare types (with the [`decl_type`] macro) that have generic parameters.
#[macro_export]
macro_rules! decl_fake_generic {
    ($name:ident, $i:expr) => {
        pub struct $name;

        impl ::ocaml_gen::OCamlDesc for $name {
            fn ocaml_desc(_env: &::ocaml_gen::Env, generics: &[&str]) -> String {
                format!("'{}", generics[$i])
            }

            fn unique_id() -> u128 {
                ::ocaml_gen::const_random!(u128)
            }
        }
    };
}
