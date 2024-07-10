extern crate alga;
#[macro_use]
extern crate quickcheck;

mod signed_int_check {
    macro_rules! check {
        ($($T:ident),* $(,)*) => {
            $(mod $T {
                use alga::general::{Additive, AbstractQuasigroup};

                quickcheck!(
                    fn prop_inv_is_latin_square(args: ($T, $T)) -> bool {
                        AbstractQuasigroup::<Additive>::prop_inv_is_latin_square(args)
                    }
                );
            })+
        }
    }

    check!(/*i8, i16,*/ i32, i64, i128);
}

mod int_check {
    macro_rules! check{
        ($($T:ident),* $(,)*) => {
            $(mod $T {
                    use alga::general::{AbstractMonoid, AbstractSemigroup, Additive, Multiplicative};

                    quickcheck!(
                        fn prop_zero_is_noop(args: ($T,)) -> bool {
                            AbstractMonoid::<Additive>::prop_operating_identity_element_is_noop(args)
                        }

                        fn prop_mul_unit_is_noop(args: ($T,)) -> bool {
                            AbstractMonoid::<Multiplicative>::prop_operating_identity_element_is_noop(args)
                        }

                        fn prop_add_is_associative(args: ($T, $T, $T)) -> bool {
                            AbstractSemigroup::<Additive>::prop_is_associative(args)
                        }

                        fn prop_mul_is_associative(args: ($T, $T, $T)) -> bool {
                            AbstractSemigroup::<Multiplicative>::prop_is_associative(args)
                        }
                    );
                }
            )+
        }
    }

    check!(/*u8, u16,*/ u32, u64, u128, /*i8, i16,*/ i32, i64, i128);
}
