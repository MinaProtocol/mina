//! Test to demonstrate asymmetric operands for binary operators using a custom type

use {
    sprs::CsVec,
    std::ops::{Add, Sub},
};

#[macro_use]
extern crate num_derive;

#[derive(Debug, PartialEq, Num, One, Zero, NumOps)]
struct ExampleLhs(i16);
#[derive(Debug, PartialEq, Num, One, Zero, NumOps)]
struct ExampleRhs(i32);
#[derive(Debug, PartialEq, Num, One, Zero, NumOps)]
struct ExampleRes(i64);

macro_rules! impl_asymmetric_op {
    ($trait:tt, $func:ident, $op:tt) => {
        impl $trait<ExampleRhs> for ExampleLhs {
            type Output = ExampleRes;

            fn $func(self, rhs: ExampleRhs) -> Self::Output {
                &self $op &rhs
            }
        }

        impl<'a, 'b> $trait<&'b ExampleRhs> for &'a ExampleLhs {
            type Output = ExampleRes;

            fn $func(self, rhs: &'b ExampleRhs) -> Self::Output {
                let ExampleLhs(lhs) = *self;
                let ExampleRhs(rhs) = *rhs;
                ExampleRes(lhs as i64 $op rhs as i64)
            }
        }
    };
}

impl_asymmetric_op!(Add, add, +);
impl_asymmetric_op!(Sub, sub, -);

#[test]
fn asymmetric_operands_add() {
    let vec_a = CsVec::new(4, vec![0, 2], vec![ExampleLhs(1), ExampleLhs(1)]);
    let vec_b = CsVec::new(
        4,
        vec![0, 1, 2],
        vec![ExampleRhs(1), ExampleRhs(1), ExampleRhs(1)],
    );

    let expected_output = CsVec::new(
        4,
        vec![0, 1, 2],
        vec![ExampleRes(2), ExampleRes(1), ExampleRes(2)],
    );
    assert_eq!(
        vec_a + vec_b,
        expected_output,
        "testing vector sum with asymmetric operands"
    );
}

#[test]
fn asymmetric_operands_sub() {
    let vec_a = CsVec::new(4, vec![0, 2], vec![ExampleLhs(1), ExampleLhs(1)]);
    let vec_b = CsVec::new(
        4,
        vec![0, 1, 2],
        vec![ExampleRhs(1), ExampleRhs(1), ExampleRhs(1)],
    );

    let expected_output = CsVec::new(
        4,
        vec![0, 1, 2],
        vec![ExampleRes(0), ExampleRes(-1), ExampleRes(0)],
    );
    assert_eq!(
        &vec_a - &vec_b,
        expected_output,
        "testing vector difference with asymmetric operands"
    );
}
