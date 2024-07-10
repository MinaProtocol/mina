use crate::{AffineCurve, ProjectiveCurve};
use ark_ff::{BigInteger, FpParameters, PrimeField};
use ark_std::vec::Vec;
use ark_std::{cfg_iter, cfg_iter_mut};

#[cfg(feature = "parallel")]
use rayon::prelude::*;

pub struct FixedBaseMSM;

impl FixedBaseMSM {
    pub fn get_mul_window_size(num_scalars: usize) -> usize {
        if num_scalars < 32 {
            3
        } else {
            super::ln_without_floats(num_scalars)
        }
    }

    pub fn get_window_table<T: ProjectiveCurve>(
        scalar_size: usize,
        window: usize,
        g: T,
    ) -> Vec<Vec<T::Affine>> {
        let in_window = 1 << window;
        let outerc = (scalar_size + window - 1) / window;
        let last_in_window = 1 << (scalar_size - (outerc - 1) * window);

        let mut multiples_of_g = vec![vec![T::zero(); in_window]; outerc];

        let mut g_outer = g;
        let mut g_outers = Vec::with_capacity(outerc);
        for _ in 0..outerc {
            g_outers.push(g_outer);
            for _ in 0..window {
                g_outer.double_in_place();
            }
        }
        cfg_iter_mut!(multiples_of_g)
            .enumerate()
            .take(outerc)
            .zip(g_outers)
            .for_each(|((outer, multiples_of_g), g_outer)| {
                let cur_in_window = if outer == outerc - 1 {
                    last_in_window
                } else {
                    in_window
                };

                let mut g_inner = T::zero();
                for inner in multiples_of_g.iter_mut().take(cur_in_window) {
                    *inner = g_inner;
                    g_inner += &g_outer;
                }
            });
        cfg_iter!(multiples_of_g)
            .map(|s| T::batch_normalization_into_affine(&s))
            .collect()
    }

    pub fn windowed_mul<T: ProjectiveCurve>(
        outerc: usize,
        window: usize,
        multiples_of_g: &[Vec<T::Affine>],
        scalar: &T::ScalarField,
    ) -> T {
        let modulus_size = <T::ScalarField as PrimeField>::Params::MODULUS_BITS as usize;
        let scalar_val = scalar.into_repr().to_bits_le();

        let mut res = multiples_of_g[0][0].into_projective();
        for outer in 0..outerc {
            let mut inner = 0usize;
            for i in 0..window {
                if outer * window + i < modulus_size && scalar_val[outer * window + i] {
                    inner |= 1 << i;
                }
            }
            res.add_assign_mixed(&multiples_of_g[outer][inner]);
        }
        res
    }

    pub fn multi_scalar_mul<T: ProjectiveCurve>(
        scalar_size: usize,
        window: usize,
        table: &[Vec<T::Affine>],
        v: &[T::ScalarField],
    ) -> Vec<T> {
        let outerc = (scalar_size + window - 1) / window;
        assert!(outerc <= table.len());

        cfg_iter!(v)
            .map(|e| Self::windowed_mul::<T>(outerc, window, table, e))
            .collect::<Vec<_>>()
    }
}
