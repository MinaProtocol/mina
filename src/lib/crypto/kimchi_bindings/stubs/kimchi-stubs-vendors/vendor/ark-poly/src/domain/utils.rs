use crate::domain::DomainCoeff;
use ark_ff::{FftField, Field};
use ark_std::vec::Vec;
#[cfg(feature = "parallel")]
use rayon::prelude::*;

// minimum size of a parallelized chunk
#[allow(unused)]
#[cfg(feature = "parallel")]
const MIN_PARALLEL_CHUNK_SIZE: usize = 1 << 7;

#[inline]
pub(crate) fn bitreverse(mut n: u32, l: u32) -> u32 {
    let mut r = 0;
    for _ in 0..l {
        r = (r << 1) | (n & 1);
        n >>= 1;
    }
    r
}

pub(crate) fn compute_powers_serial<F: Field>(size: usize, root: F) -> Vec<F> {
    compute_powers_and_mul_by_const_serial(size, root, F::one())
}

pub(crate) fn compute_powers_and_mul_by_const_serial<F: Field>(
    size: usize,
    root: F,
    c: F,
) -> Vec<F> {
    let mut value = c;
    (0..size)
        .map(|_| {
            let old_value = value;
            value *= root;
            old_value
        })
        .collect()
}

#[allow(unused)]
#[cfg(feature = "parallel")]
pub(crate) fn compute_powers<F: Field>(size: usize, g: F) -> Vec<F> {
    if size < MIN_PARALLEL_CHUNK_SIZE {
        return compute_powers_serial(size, g);
    }
    // compute the number of threads we will be using.
    use ark_std::cmp::{max, min};
    let num_cpus_available = rayon::current_num_threads();
    let num_elem_per_thread = max(size / num_cpus_available, MIN_PARALLEL_CHUNK_SIZE);
    let num_cpus_used = size / num_elem_per_thread;

    // Split up the powers to compute across each thread evenly.
    let res: Vec<F> = (0..num_cpus_used)
        .into_par_iter()
        .flat_map(|i| {
            let offset = g.pow(&[(i * num_elem_per_thread) as u64]);
            // Compute the size that this chunks' output should be
            // (num_elem_per_thread, unless there are less than num_elem_per_thread elements remaining)
            let num_elements_to_compute = min(size - i * num_elem_per_thread, num_elem_per_thread);
            let res = compute_powers_and_mul_by_const_serial(num_elements_to_compute, g, offset);
            res
        })
        .collect();
    res
}

#[cfg(feature = "parallel")]
fn log2_floor(num: usize) -> u32 {
    if num == 0 {
        0
    } else {
        1usize.leading_zeros() - num.leading_zeros()
    }
}

#[cfg(feature = "parallel")]
pub(crate) fn best_fft<T: DomainCoeff<F>, F: FftField>(
    a: &mut [T],
    omega: F,
    log_n: u32,
    serial_fft: fn(&mut [T], F, u32),
) {
    let num_cpus = rayon::current_num_threads();
    let log_cpus = log2_floor(num_cpus);
    if log_n <= log_cpus {
        serial_fft(a, omega, log_n);
    } else {
        parallel_fft(a, omega, log_n, log_cpus, serial_fft);
    }
}

#[cfg(not(feature = "parallel"))]
#[inline]
pub(crate) fn best_fft<T: DomainCoeff<F>, F: FftField>(
    a: &mut [T],
    omega: F,
    log_n: u32,
    serial_fft: fn(&mut [T], F, u32),
) {
    serial_fft(a, omega, log_n)
}

#[cfg(feature = "parallel")]
pub(crate) fn parallel_fft<T: DomainCoeff<F>, F: FftField>(
    a: &mut [T],
    omega: F,
    log_n: u32,
    log_cpus: u32,
    serial_fft: fn(&mut [T], F, u32),
) {
    assert!(log_n >= log_cpus);
    // For documentation purposes, comments explain things
    // as though `a` is a polynomial that we are trying to evaluate.

    // Partition `a` equally into the number of threads.
    // each partition is then of size m / num_threads.
    let m = a.len();
    let num_threads = 1 << (log_cpus as usize);
    let num_cosets = num_threads;
    assert_eq!(m % num_threads, 0);
    let coset_size = m / num_threads;

    // We compute the FFT non-mutatively first in tmp first,
    // and then shuffle it back into a.
    // The evaluations are going to be arranged in cosets, each of size |a| / num_threads.
    // so the first coset is (1, g^{num_cosets}, g^{2*num_cosets}, etc.)
    // the second coset is (g, g^{1 + num_cosets}, g^{1 + 2*num_cosets}, etc.)
    // These are cosets with generator g^{num_cosets}, and varying shifts.
    let mut tmp = vec![vec![T::zero(); coset_size]; num_cosets];
    let new_omega = omega.pow(&[num_cosets as u64]);
    let new_two_adicity = ark_ff::utils::k_adicity(2, coset_size);

    // For each coset, we first build a polynomial of degree |coset size|,
    // whose evaluations over coset k will agree with the evaluations of a over the coset.
    // Denote the kth such polynomial as poly_k
    tmp.par_iter_mut()
        .enumerate()
        .for_each(|(k, kth_poly_coeffs)| {
            // Shuffle into a sub-FFT
            let omega_k = omega.pow(&[k as u64]);
            let omega_step = omega.pow(&[(k * coset_size) as u64]);

            let mut elt = F::one();
            // Construct kth_poly_coeffs, which is a polynomial whose evaluations on this coset
            // should equal the evaluations of a on this coset.
            // `kth_poly_coeffs[i] = sum_{c in num_cosets} g^{k * (i + c * |coset|)} * a[i + c * |coset|]`
            // Where c represents the index of the coset being considered.
            // multiplying by g^{k*i} corresponds to the shift for just being in a different coset.
            //
            // TODO: Come back and improve the speed, and make this a more 'normal' Cooley-Tukey.
            // This appears to be an FFT of the polynomial
            // `P(x) = sum_{c in |coset|} a[i + c |coset|] * x^c`
            // onto this coset.
            // However this is being evaluated in time O(N) instead of time O(|coset|log(|coset|)).
            // If this understanding is the case, its not doing standard Cooley-Tukey.
            // At the moment, this has time complexity of at least 2*N field mul's per thread,
            // so we will be getting pretty bad parallelism.
            // Exact complexity per thread atm is `2N + (N/num threads)log(N/num threads)` field muls
            // Compare to the time complexity of serial is Nlog(N) field muls), with log(N) in [15, 25]
            for i in 0..coset_size {
                for c in 0..num_threads {
                    let idx = i + (c * coset_size);
                    // t = the value of a corresponding to the ith element of the sth coset.
                    let mut t = a[idx];
                    // elt = g^{k * idx}
                    t *= elt;
                    kth_poly_coeffs[i] += t;
                    elt *= &omega_step;
                }
                elt *= &omega_k;
            }

            // Perform sub-FFT
            // Since the sub-FFT is mutative, after this point
            // `kth_poly_coeffs` should be renamed `kth_coset_evals`
            serial_fft(kth_poly_coeffs, new_omega, new_two_adicity);
        });

    // shuffle the values computed above into a
    // The evaluations of a should be ordered as (1, g, g^2, ...)
    a.iter_mut()
        .enumerate()
        .for_each(|(i, a)| *a = tmp[i % num_cosets][i / num_cosets]);
}

/// An iterator over the elements of a domain.
pub struct Elements<F: FftField> {
    pub(crate) cur_elem: F,
    pub(crate) cur_pow: u64,
    pub(crate) size: u64,
    pub(crate) group_gen: F,
}

impl<F: FftField> Iterator for Elements<F> {
    type Item = F;
    fn next(&mut self) -> Option<F> {
        if self.cur_pow == self.size {
            None
        } else {
            let cur_elem = self.cur_elem;
            self.cur_elem *= &self.group_gen;
            self.cur_pow += 1;
            Some(cur_elem)
        }
    }
}
