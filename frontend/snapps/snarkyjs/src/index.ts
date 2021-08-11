import { Field as F, Circuit as C } from './bindings/snarky2';
import { Snapp as S } from './mina';



export type Field = F;
export type Circuit = C;
export type Snapp = S;







// make sure examples compile
import { circuit } from './examples/matrix_mul';

export const matrix_mul_circuit = circuit;

import { main as m } from './examples/schnorr_sign';
export const schnorr_sign = m;

import { main } from './examples/exchange';

export const exchange = main;
exchange();


// for testing tests
export const five: number = 5;
