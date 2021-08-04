import * as Snarky from './bindings/snarky';
import * as Mina from './mina';

export type Field = Snarky.Field;
export type Circuit = Snarky.Circuit;
export type Snapp = Mina.Snapp;

// make sure examples compile
import * as MatrixMul from './examples/matrix_mul';
export const matrix_mul_circuit = MatrixMul.circuit;

import * as SchnorrSign from './examples/schnorr_sign';
export const schnorr_sign = SchnorrSign.main;

// for testing tests
export const five: number = 5;
