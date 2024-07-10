use crate::general::{
    AbstractField, AbstractGroup, AbstractGroupAbelian, AbstractLoop, AbstractMagma,
    AbstractModule, AbstractMonoid, AbstractQuasigroup, AbstractRing, AbstractRingCommutative,
    AbstractSemigroup, Additive, ClosedAdd, ClosedDiv, ClosedMul, ClosedNeg, ClosedSub,
    Multiplicative,
};
use num::{One, Zero};

macro_rules! specialize_structures(
    // **With type parameters** for the trait being implemented.
    ($specialized: ident, $abstract_trait: ident<$($ops: ident),*> : $($bounds: ident)*) => {
        /// [Alias] Algebraic structure specialized for one kind of operation.
        pub trait $specialized: $abstract_trait<$($ops),*> $(+ $bounds)* { }
        impl<T: $abstract_trait<$($ops),*> $(+ $bounds)*> $specialized for T { }
    };
    // **Without type parameters** for the trait being implemented.
    ($specialized: ident, $abstract_trait: ident : $($bounds: ident)*) => {
        /// [Alias] Algebraic structure specialized for one kind of operation.
        pub trait $specialized: $abstract_trait $(+ $bounds)* { }
        impl<T: $abstract_trait $(+ $bounds)*> $specialized for T { }
    }
);

specialize_structures!(AdditiveMagma,        AbstractMagma<Additive>        : );
specialize_structures!(AdditiveQuasigroup,   AbstractQuasigroup<Additive>   : AdditiveMagma ClosedSub);
specialize_structures!(AdditiveLoop,         AbstractLoop<Additive>         : AdditiveQuasigroup ClosedNeg Zero);
specialize_structures!(AdditiveSemigroup,    AbstractSemigroup<Additive>    : AdditiveMagma ClosedAdd);
specialize_structures!(AdditiveMonoid,       AbstractMonoid<Additive>       : AdditiveSemigroup Zero);
specialize_structures!(AdditiveGroup,        AbstractGroup<Additive>        : AdditiveLoop AdditiveMonoid);
specialize_structures!(AdditiveGroupAbelian, AbstractGroupAbelian<Additive> : AdditiveGroup);

specialize_structures!(MultiplicativeMagma,      AbstractMagma<Multiplicative>      : );
specialize_structures!(MultiplicativeQuasigroup, AbstractQuasigroup<Multiplicative> : MultiplicativeMagma ClosedDiv);
specialize_structures!(MultiplicativeLoop,       AbstractLoop<Multiplicative>       : MultiplicativeQuasigroup One);
specialize_structures!(MultiplicativeSemigroup,  AbstractSemigroup<Multiplicative>  : MultiplicativeMagma ClosedMul);
specialize_structures!(MultiplicativeMonoid,     AbstractMonoid<Multiplicative>     : MultiplicativeSemigroup One);
specialize_structures!(MultiplicativeGroup,      AbstractGroup<Multiplicative>      : MultiplicativeLoop MultiplicativeMonoid);
specialize_structures!(MultiplicativeGroupAbelian, AbstractGroupAbelian<Multiplicative> : MultiplicativeGroup);

specialize_structures!(Ring,            AbstractRing:            AdditiveGroupAbelian MultiplicativeMonoid);
specialize_structures!(RingCommutative, AbstractRingCommutative: Ring);
specialize_structures!(Field,           AbstractField:           RingCommutative MultiplicativeGroupAbelian);

/// A module which overloads the `*` and `+` operators.
pub trait Module:
    AbstractModule<AbstractRing = <Self as Module>::Ring>
    + AdditiveGroupAbelian
    + ClosedMul<<Self as Module>::Ring>
{
    /// The underlying scalar field.
    type Ring: RingCommutative;
}

// FIXME: unfortunately, Module cannot be auto-impl-ed.
impl<N: RingCommutative + num::NumAssign> Module for num_complex::Complex<N> {
    type Ring = N;
}

macro_rules! impl_module(
    ($($T:ty),*) => {
        $(impl Module for $T{
            type Ring = $T;
        })*
    }
);

impl_module!(i8, i16, i32, i64, isize, f32, f64);
