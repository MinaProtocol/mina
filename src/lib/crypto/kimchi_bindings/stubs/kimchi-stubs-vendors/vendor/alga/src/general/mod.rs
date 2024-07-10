// Copyright 2013-2014 The Algebra Developers.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

//! Fundamental algebraic structures.
//!
//! For most applications requiring an abstraction over the reals, `RealField`
//! should be sufficient.
//!
//! ## Algebraic properties
//!
//! The goal of algebraic structures is to allow elements of sets to be combined together using one
//! or several operators. The number and properties of those operators characterize the algebraic
//! structure. Abstract operators are usually noted `∘`, `+`, or `×`. The last two are preferred
//! when their behavior conform with the usual meaning of addition and multiplication of reals.
//! Let `Self` be a set. Here is a list of the most common properties those operator may fulfill:
//!
//! ~~~notrust
//! (Closure)       a, b ∈ Self ⇒ a ∘ b ∈ Self,
//! (Divisibility)  ∀ a, b ∈ Self, ∃! r, l ∈ Self such that l ∘ a = b and a ∘ r = b
//! (Invertibility) ∃ e ∈ Self, ∀ a ∈ Self, ∃ r, l ∈ Self such that l ∘ a = a ∘ r = e
//!                 If the right and left inverse are equal they are usually noted r = l = a⁻¹.
//! (Associativity) ∀ a, b, c ∈ Self, (a ∘ b) ∘ c = a ∘ (b ∘ c)
//! (Neutral Elt.)  ∃ e ∈ Self, ∀ a ∈ Self, e ∘ a = a ∘ e = a
//! (Commutativity) ∀ a, b ∈ Self, a ∘ b = b ∘ a
//! ~~~
//!
//! ## Identity elements
//!
//! Two traits are provided that allow the definition of the additive and
//! multiplicative identity elements:
//!
//! - `IdentityAdditive`
//! - `IdentityMultiplicative`
//!
//! ## AbstractGroup-like structures
//!
//! These structures are provided for both the addition and multiplication.
//!
//! These can be derived automatically by `alga_traits` attribute from `alga_derive` crate.
//!
//! ~~~notrust
//!            AbstractMagma
//!                 |
//!         _______/ \______
//!        /                \
//!  divisibility       associativity
//!       |                  |
//!       V                  V
//! AbstractQuasigroup AbstractSemigroup
//!       |                  |
//!   identity            identity
//!       |                  |
//!       V                  V
//!  AbstractLoop       AbstractMonoid
//!       |                  |
//!  associativity     invertibility
//!        \______   _______/
//!               \ /
//!                |
//!                V
//!          AbstractGroup
//!                |
//!          commutativity
//!                |
//!                V
//!      AbstractGroupAbelian
//! ~~~
//!
//! The following traits are provided:
//!
//! - (`Abstract`|`Additive`|`Multiplicative`)`Magma`
//! - (`Abstract`|`Additive`|`Multiplicative`)`Quasigroup`
//! - (`Abstract`|`Additive`|`Multiplicative`)`Loop`
//! - (`Abstract`|`Additive`|`Multiplicative`)`Semigroup`
//! - (`Abstract`|`Additive`|`Multiplicative`)`Monoid`
//! - (`Abstract`|`Additive`|`Multiplicative`)`Group`
//! - (`Abstract`|`Additive`|`Multiplicative`)`GroupAbelian`
//!
//! ## Ring-like structures
//!
//! These can be derived automatically by `alga_traits` attribute from `alga_derive` crate.
//!
//! ~~~notrust
//!      GroupAbelian           Monoid
//!           \________   ________/
//!                    \ /
//!                     |
//!                     V
//!                    Ring
//!                     |
//!            commutativity_of_mul
//!                     |
//!                     V
//!              RingCommutative           GroupAbelian
//!                      \_______   ___________/
//!                              \ /
//!                               |
//!                               V
//!                             Field
//! ~~~
//!
//! The following traits are provided:
//!
//! - `Ring`
//! - `RingCommutative`
//! - `Field`
//!
//! ## Module-like structures
//!
//! ~~~notrust
//!     GroupAbelian         RingCommutative
//!           \______         _____/
//!                  \       /
//!                   |     |
//!                   V     V
//!                Module<Scalar>          Field
//!                    \______         _____/
//!                           \       /
//!                            |     |
//!                            V     V
//!                      VectorSpace<Scalar>
//! ~~~
//!
//! The following traits are provided:
//!
//! - `Module`
//! - `VectorSpace`
//!
//! # Quickcheck properties
//!
//! Functions are provided to test that algebraic properties like
//! associativity and commutativity hold for a given set of arguments.
//!
//! These tests can be automatically derived by `alga_quickcheck` attribute from `alga_derive` crate.
//!
//! For example:
//!
//! ~~~.ignore
//! use algebra::general::SemigroupMultiplicative;
//!
//! quickcheck! {
//!     fn prop_mul_is_associative(args: (i32, i32, i32)) -> bool {
//!         SemigroupMultiplicative::prop_mul_is_associative(args)
//!     }
//! }
//! ~~~

pub use self::identity::{Id, Identity};
pub use self::operator::{
    Additive, ClosedAdd, ClosedDiv, ClosedMul, ClosedNeg, ClosedSub, Multiplicative, Operator,
    TwoSidedInverse,
};
pub use self::subset::{SubsetOf, SupersetOf};

pub use self::complex::ComplexField;
pub use self::lattice::{JoinSemilattice, Lattice, MeetSemilattice};
pub use self::module::AbstractModule;
pub use self::one_operator::{
    AbstractGroup, AbstractGroupAbelian, AbstractLoop, AbstractMagma, AbstractMonoid,
    AbstractQuasigroup, AbstractSemigroup,
};
pub use self::real::RealField;
pub use self::specialized::{
    AdditiveGroup, AdditiveGroupAbelian, AdditiveLoop, AdditiveMagma, AdditiveMonoid,
    AdditiveQuasigroup, AdditiveSemigroup, Field, Module, MultiplicativeGroup,
    MultiplicativeGroupAbelian, MultiplicativeLoop, MultiplicativeMagma, MultiplicativeMonoid,
    MultiplicativeQuasigroup, MultiplicativeSemigroup, Ring, RingCommutative,
};
pub use self::two_operators::{AbstractField, AbstractRing, AbstractRingCommutative};

#[macro_use]
mod one_operator;
mod complex;
mod identity;
mod lattice;
mod module;
mod operator;
mod real;
mod specialized;
mod subset;
mod two_operators;
#[doc(hidden)]
pub mod wrapper;

#[deprecated(note = "This has been renamed `RealField`.")]
/// The field of reals. This has been renamed to `RealField`.
pub trait Real: RealField {}

impl<T: RealField> Real for T {}
