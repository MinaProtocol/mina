Below is performance information about several preprocessing zkSNARKs in `libsnark` that work with the R1CS relation.

# Empirical performance

We benchmark proof systems on an R1CS instance with 10<sup>6</sup> constraints and 10<sup>6</sup> variables, of which 10 are input variables. The benchmarks were obtained using a 3.40 GHz Intel Core i7-4770 CPU, in single-threaded mode, using the BN128 curve.

Our R1CS instance was chosen to be dense, therefore the generator and prover runtimes given here are upper bounds on what one would expect for real world (i.e. sparse) R1CS instances.

The prover spends almost all of its time either doing FFTs or multiexponentiations. The percentage of time doing FFTs is given in the table.

Abbreviations used: <i>PK</i> = proving key, <i>VK</i> = verifying key, <i>MB</i> = megabyte (10<sup>6</sup> bytes), #G<sub>1</sub>/#G<sub>2</sub> = number of elements of the respective group in a proof/key.

| Proof system | Generator time, s | Prover time, s | Verifier time, ms | Prover time spent in FFTs, % |
| --- | --: | --: | --: | --: |
| [PGHR13/BCTV14a](r1cs_ppzksnark) | 104.85 | 128.60 | 4.3 | 7% |
| [Groth16](r1cs_gg_ppzksnark) | 72.53 | 84.01 | 1.3 | 11% |
| [GM17](r1cs_se_ppzksnark) | 100.41 | 116.42 | 2.3 | 12% |

| Proof system | | <i>PK</i> size | || | <i>VK</i> size | || | Proof size | |
| --- | --: | --: | --: | --- | --: | --: | --: | --- | --: | --: | --: |
| | <i>MB</i> | #G<sub>1</sub> | #G<sub>2</sub> || bytes| #G<sub>1</sub> | #G<sub>2</sub> || bytes | #G<sub>1</sub> | #G<sub>2</sub> |
| [PGHR13/BCTV14a](r1cs_ppzksnark) | 312 | 7048603 | 1000004 || 812 | 12 | 5 || 287 | 7 | 1 |
| [Groth16](r1cs_gg_ppzksnark) | 201 | 4048574 | 1000004 || 558 | 10 | 2 || 127 | 2 | 1 |
| [GM17](r1cs_se_ppzksnark) | 385 | 8097184 | 2000014 || 605 | 13 | 3 || 127 | 2 | 1 |

# Asymptotic performance

We estimate asymptotic performance of the proof systems.

We use the same abbreviations as above, along with additional notation: M = number of constraints in R1CS instance, N = number of variables in R1CS instance, n = number of inputs in R1CS instance.

Constant terms were dropped from all columns except number of FFTs in the prover and domain size.

The number of exponentiations in the prover and the generator are the same. In the generator, they are groups of single-base exponentiations (calculating [a<sup>e<sub>1</sub></sup>, a<sup>e<sub>2</sub></sup>, ...]), and in the prover, they are groups of multiple exponentiations where only the product of the results matters (calculating a<sub>1</sub><sup>e<sub>1</sub></sup> &middot; a<sub>2</sub><sup>e<sub>2</sub></sup> &middot; ...). Thus the table gives not only the total number of base/exponent pairs, but also how they are grouped.

| Proof system | FFTs in prover | | | Exponentiations in generator/prover | |
| --- | :---: | :---: | --- | :---: | :---: |
| | count | domain size | | #G<sub>1</sub> | #G<sub>2</sub> |
| [PGHR13/BCTV14a](r1cs_ppzksnark) | 7 | M+n+1 | | 6N+M+n = 6*(N) + (M+n) | N |
| [Groth16](r1cs_gg_ppzksnark) | 7 | M+n+1 | | 3N+M = 2*(N) + (M+n) + (N-n) |  N |
| [GM17](r1cs_se_ppzksnark) |  5 | 2M+2n+1 | | 3N+5M+4n = 2*(N+M+n) + (N+M) + (2M+2n) |  (N+M+n) |

| Proof system | <i>PK</i> | | | <i>VK</i> | |
| --- | :---: | :---: | --- | :---: | :---: |
| | #G<sub>1</sub> | #G<sub>2</sub> | | #G<sub>1</sub> | #G<sub>2</sub> |
| [PGHR13/BCTV14a](r1cs_ppzksnark) | 6N+M+n | N | | n | O(1) |
| [Groth16](r1cs_gg_ppzksnark) | 3N+M | N | | n | O(1) |
| [GM17](r1cs_se_ppzksnark) |  3N+5M+4n | N+M+n | | n | O(1) |
