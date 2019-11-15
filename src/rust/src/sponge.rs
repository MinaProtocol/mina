use algebra::Field;
const rounds_full : usize = 8;

const rounds_partial : usize = 33;

const half_rounds_full : usize = rounds_full / 2;

pub trait Sponge<Input, Digest> {
    type Params;

    fn new() -> Self;

    fn absorb(&mut self, params : & Self::Params, x : &Input);

    fn squeeze(&mut self, params : &Self::Params) -> Digest ;
}

// x^5
fn sbox<F : Field>(x : F) -> F {
    let mut res = x;
    res.square_in_place(); //x^2
    res.square_in_place(); //x^4
    res.mul_assign(&x);
    res
}

fn apply_matrix<F:Field>(
    mat: & Vec<Vec<F>>,
    v : & Vec<F>) -> Vec<F> {
    mat.iter().map(|row| {
        let mut res = F::zero();
        for (i, r) in row.iter().enumerate() {
            res += &v[i].mul(r);
        }
        res
    }).collect()
}


enum SpongeState {
    Absorbed(usize),
    Squeezed(usize)
}

pub struct ArithmeticSpongeParams<F:Field> {
    round_constants: Vec<Vec<F>>,
    mds: Vec<Vec<F>>
}

pub struct ArithmeticSponge<F: Field> {
    sponge_state : SpongeState,
    rate : usize,
    state: Vec<F>,
}

impl<F: Field> ArithmeticSponge<F> {
    fn poseidon_block_cipher(&mut self, params : & ArithmeticSpongeParams<F>) {
        for r in 0..half_rounds_full {
            for (i, x) in params.round_constants[r].iter().enumerate() {
                self.state[i].add_assign(&x);
            }
            for i in 0..self.state.len() {
                self.state[i] = sbox(self.state[i]);
            }
            let new_state = apply_matrix(&params.mds, &self.state);
            for i in 0..new_state.len() {
                self.state[i] = new_state[i];
            }
        }

        for r in 0..rounds_partial {
            for (i, x) in params.round_constants[half_rounds_full + r].iter().enumerate() {
                self.state[i].add_assign(&x);
            }
            self.state[0] = sbox(self.state[0]);
            let new_state = apply_matrix(&params.mds, &self.state);
            for i in 0..new_state.len() {
                self.state[i] = new_state[i];
            }
        }

        for r in 0..half_rounds_full {
            for (i, x) in params.round_constants[half_rounds_full + rounds_partial + r].iter().enumerate() {
                self.state[i].add_assign(&x);
            }
            for i in 0..self.state.len() {
                self.state[i] = sbox(self.state[i]);
            }
            let new_state = apply_matrix(&params.mds, &self.state);
            for i in 0..new_state.len() {
                self.state[i] = new_state[i];
            }
        }
    }
}

impl<F: Field> Sponge<F, F> for ArithmeticSponge<F> {
    type Params = ArithmeticSpongeParams<F>;

    fn new() -> ArithmeticSponge<F> {
        let capacity = 1;
        let rate = 2;

        let mut state = Vec::with_capacity(capacity + rate);

        for _ in 0..(capacity + rate) {
            state.push(F::zero());
        }

        ArithmeticSponge {
            state,
            rate,
            sponge_state: SpongeState::Absorbed(0)
        }
    }

    fn absorb(&mut self, params : &ArithmeticSpongeParams<F>, x : &F) {
        match self.sponge_state {
            SpongeState::Absorbed(n) => {
                if n == self.rate {
                    self.poseidon_block_cipher(params);
                    self.sponge_state = SpongeState::Absorbed(1);
                    self.state[0].add_assign(x);
                } else {
                    self.sponge_state = SpongeState::Absorbed(n + 1);
                    self.state[n].add_assign(x);
                }
            },
            SpongeState::Squeezed(n) => {
                self.state[0].add_assign(x);
                self.sponge_state = SpongeState::Absorbed(1);
            }
        }
    }

    fn squeeze(&mut self, params : &ArithmeticSpongeParams<F>) -> F {
        match self.sponge_state {
            SpongeState::Squeezed(n) => {
                if n == self.rate {
                    self.poseidon_block_cipher(params);
                    self.sponge_state = SpongeState::Squeezed(1);
                    self.state[0]
                } else {
                    self.sponge_state = SpongeState::Squeezed(n + 1);
                    self.state[n]
                }
            },
            SpongeState::Absorbed(n) => {
                self.poseidon_block_cipher(params);
                self.sponge_state = SpongeState::Squeezed(1);
                self.state[0]
            }
        }
    }
}

