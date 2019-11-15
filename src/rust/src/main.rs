use algebra::{Field, PrimeField};
use algebra::UniformRand;
use poly_commit::SinglePolynomialCommitment;
use poly_commit::Polynomial;
use rand::thread_rng;
mod sponge;
use sponge::ArithmeticSponge;
use either::Either;
use ff_fft::{EvaluationDomain, Evaluations as EvaluationsOnDomain};
use std::collections::HashMap;

fn commit<F : Field, SinglePC : SinglePolynomialCommitment<F>>(
    ck : &SinglePC::CommitterKey,
    p : &Polynomial<F>) -> SinglePC::Commitment {
    let (comm, rand) = SinglePC::commit(ck, p, None, None).unwrap();
    comm
}

fn main() {
}

enum Message<F, C> {
    Field(F),
    Commitment(C)
}

fn sigma_gh2
< 'a, F : PrimeField
, SinglePC : SinglePolynomialCommitment<F>>
( 
    ck : &SinglePC::CommitterKey,
    domain_h : EvaluationDomain<F>,
 domain_k : EvaluationDomain<F>,
 beta_1 : F,
 eta_a : F,
 eta_b : F,
 eta_c : F,
    a_row_evals: &'a EvaluationsOnDomain<F>,
    a_col_evals: &'a EvaluationsOnDomain<F>,
    a_val_evals: &'a EvaluationsOnDomain<F>,

    b_row_evals: &'a EvaluationsOnDomain<F>,
    b_col_evals: &'a EvaluationsOnDomain<F>,
    b_val_evals: &'a EvaluationsOnDomain<F>,

    c_row_evals: &'a EvaluationsOnDomain<F>,
    c_col_evals: &'a EvaluationsOnDomain<F>,
    c_val_evals: &'a EvaluationsOnDomain<F>)
    -> (F, SinglePC::Commitment, SinglePC::Commitment) {
    let mut a_beta_1_vals_on_H : HashMap<F, F> = HashMap::new();
    let mut b_beta_1_vals_on_H : HashMap<F, F> = HashMap::new();
    let mut c_beta_1_vals_on_H : HashMap<F, F> = HashMap::new();

    let r_x_x_precomp: HashMap<_, _> = domain_h.elements().zip(domain_h.batch_eval_unnormalized_bivariate_lagrange_poly_with_same_inputs()).collect();
    let r_beta_1_x_precomp: HashMap<_, _> = domain_h.elements().zip(domain_h.batch_eval_unnormalized_bivariate_lagrange_poly_with_diff_inputs(beta_1)).collect();

    for k in 0..domain_k.size() {
        // TODO: parallelize
        let a_col_at_kappa = a_col_evals[k];
        let a_row_at_kappa = a_row_evals[k];
        let to_add_a = r_x_x_precomp[&a_row_at_kappa] * &r_beta_1_x_precomp[&a_col_at_kappa] * &a_val_evals[k];
        *a_beta_1_vals_on_H.entry(a_row_at_kappa).or_insert(F::zero()) += &to_add_a;

        let b_col_at_kappa = b_col_evals[k];
        let b_row_at_kappa = b_row_evals[k];
        let to_add_b = r_x_x_precomp[&b_row_at_kappa] * &r_beta_1_x_precomp[&b_col_at_kappa] * &b_val_evals[k];
        *b_beta_1_vals_on_H.entry(b_row_at_kappa).or_insert(F::zero()) += &to_add_b;

        let c_col_at_kappa = c_col_evals[k];
        let c_row_at_kappa = c_row_evals[k];
        let to_add_c = r_x_x_precomp[&c_row_at_kappa] * &r_beta_1_x_precomp[&c_col_at_kappa] * &c_val_evals[k];
        *c_beta_1_vals_on_H.entry(c_row_at_kappa).or_insert(F::zero()) += &to_add_c;
    }

    let summed_m_beta_1_evals = domain_h.elements().map(|h_elem| {
            eta_a * a_beta_1_vals_on_H.get(&h_elem).unwrap_or(&F::zero())
        + &(eta_b * b_beta_1_vals_on_H.get(&h_elem).unwrap_or(&F::zero()))
        + &(eta_c * c_beta_1_vals_on_H.get(&h_elem).unwrap_or(&F::zero()))
    }).collect::<Vec<_>>();

    let summed_m_beta_1 = EvaluationsOnDomain::from_vec_and_domain(summed_m_beta_1_evals, domain_h).interpolate();

    let q_2 = &r_alpha_poly * &summed_m_beta_1;

    let (h_2, x_g_2) = q_2.divide_by_vanishing_poly(domain_h).unwrap();
    let sigma_2 = x_g_2.coeffs[0] * &domain_h.size_as_field_element;
    let g_2 = Polynomial::from_coefficients_slice(&x_g_2.coeffs[1..]);
    drop(x_g_2);

    ( sigma_2, commit::<F, SinglePC>(ck, &g_2), h_2 )
}

fn prover
< F : Field
, SinglePC : SinglePolynomialCommitment<F>
, Sponge : sponge::Sponge< Message<F, SinglePC::Commitment>, F> >
(ck : &SinglePC::CommitterKey, sponge_params :&Sponge::Params)  {
    let mut s = Sponge::new();
    let a1_2 : Polynomial<F> = (None).unwrap();
    let x : SinglePC::Commitment = commit::<F, SinglePC>(ck, &a1_2);
    let x : SinglePC::Commitment = commit::<F, SinglePC>(ck, (None).unwrap());

    s.absorb(sponge_params, &Message::Commitment(x.clone()));

    let y = s.squeeze(sponge_params);

    s.absorb(sponge_params, &Message::Field(y.clone()));
}
