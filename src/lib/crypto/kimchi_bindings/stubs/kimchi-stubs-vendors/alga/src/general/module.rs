use crate::general::{
    AbstractGroupAbelian, AbstractRingCommutative, Additive, Multiplicative, Operator,
};

/// A module combines two sets: one with an Abelian group structure and another with a
/// commutative ring structure.
///
/// `OpGroup` denotes the Abelian group operator (usually the addition). In addition, and external
/// multiplicative law noted `∘` is defined. Let `S` be the ring with multiplicative operator
/// `OpMul` noted `×`, multiplicative identity element noted `1`, and additive operator `OpAdd`.
/// Then:
///
/// ```notrust
/// ∀ a, b ∈ S
/// ∀ x, y ∈ Self
///
/// a ∘ (x + y) = (a ∘ x) + (a ∘ y)
/// (a + b) ∘ x = (a ∘ x) + (b ∘ x)
/// (a × b) ∘ x = a ∘ (b ∘ x)
/// 1 ∘ x       = x
/// ```
pub trait AbstractModule<
    OpGroup: Operator = Additive,
    OpAdd: Operator = Additive,
    OpMul: Operator = Multiplicative,
>: AbstractGroupAbelian<OpGroup>
{
    /// The underlying scalar field.
    type AbstractRing: AbstractRingCommutative<OpAdd, OpMul>;

    /// Multiplies an element of the ring with an element of the module.
    fn multiply_by(&self, r: Self::AbstractRing) -> Self;
}

impl<
        N: AbstractRingCommutative<Additive, Multiplicative> + num::Num + crate::general::ClosedNeg,
    > AbstractModule<Additive, Additive, Multiplicative> for num_complex::Complex<N>
{
    type AbstractRing = N;

    #[inline]
    fn multiply_by(&self, r: N) -> Self {
        self.clone() * r
    }
}

macro_rules! impl_abstract_module(
    ($($T:ty),*) => {
        $(impl AbstractModule for $T {
            type AbstractRing = $T;

            #[inline]
            fn multiply_by(&self, r: $T) -> Self {
                self.clone() * r
            }
        })*
    }
);

impl_abstract_module!(i8, i16, i32, i64, isize, f32, f64);

