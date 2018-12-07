#include <libsnark/caml/caml_bn128.hpp>

extern "C" {
using namespace libsnark;

protoboard<FieldT>* camlsnark_bn128_protoboard_create() {
  return new protoboard<FieldT>();
}

void camlsnark_bn128_protoboard_delete(protoboard<FieldT>* pb) {
  delete pb;
}

void camlsnark_bn128_protoboard_set_input_sizes(protoboard<FieldT>* pb, int primary_input_size) {
  return pb->set_input_sizes(primary_input_size);
}

int camlsnark_bn128_protoboard_num_variables(protoboard<FieldT>* pb) {
  return pb->num_variables();
}

std::vector<FieldT>* camlsnark_bn128_protoboard_auxiliary_input(protoboard<FieldT>* pb) {
  return new std::vector<FieldT>(pb->auxiliary_input());
}

void camlsnark_bn128_protoboard_augment_variable_annotation(
    protoboard<FieldT>* pb,
    pb_variable<FieldT>* var,
    char* annotation
    ) {
  std::string str(annotation);
  pb->augment_variable_annotation(*var, str);
}

pb_variable<FieldT>* camlsnark_bn128_protoboard_allocate_variable(protoboard<FieldT>* pb) {
  pb_variable<FieldT>* x = new pb_variable<FieldT>();
  x->allocate(*pb, "pb_var");
  return x;
}

pb_variable_array<FieldT>* camlsnark_bn128_protoboard_allocate_variable_array(protoboard<FieldT>* pb, int n) {
  pb_variable_array<FieldT>* x = new pb_variable_array<FieldT>();
  x->allocate(*pb, n, "pb_var_array");
  return x;
}

pb_variable<FieldT>* 
camlsnark_bn128_protoboard_variable_of_int(int i) {
  return new pb_variable<FieldT>(i);
}

void camlsnark_bn128_protoboard_variable_delete(pb_variable<FieldT>* v) {
  delete v;
}

int camlsnark_bn128_protoboard_variable_index(pb_variable<FieldT>* v) {
  return v->index;
}

pb_variable_array<FieldT>* camlsnark_bn128_protoboard_variable_array_create() {
  return new pb_variable_array<FieldT>();
}

void camlsnark_bn128_protoboard_variable_array_delete(pb_variable_array<FieldT>* arr) {
  delete arr;
}

void camlsnark_bn128_protoboard_variable_array_emplace_back(pb_variable_array<FieldT>* arr, pb_variable<FieldT>* v) {
  arr->emplace_back(*v);
}

pb_variable<FieldT>* camlsnark_bn128_protoboard_variable_array_get(
    pb_variable_array<FieldT>* arr, int i) {
  return new pb_variable<FieldT>((*arr)[i]);
}

linear_combination<FieldT> camlsnark_bn128_linear_combination_renumber(
    linear_combination<FieldT> &lc,
    std::vector< linear_combination<FieldT> > &changes,
    int aux_shift) {
  linear_combination<FieldT> result = linear_combination<FieldT>();

  int num_terms = lc.terms.size();
  int num_changes = changes.size();

  for (int i = 0; i < num_terms; ++i) {
    linear_term<FieldT>& term = lc.terms[i];
    int term_index = term.index - 1;
    if (term_index >= 0) {
      if (term_index < num_changes) {
        FieldT coeff = term.coeff;
        linear_combination<FieldT>& subst_lc = changes[term_index];
        std::vector<linear_term<FieldT>>& subst = subst_lc.terms;
        int subst_size = subst.size();
        for (int j = 0; j < subst_size; ++j) {
          linear_term<FieldT>& subst_term = subst[j];
          result.add_term(
              variable<FieldT>(subst_term.index), coeff * subst_term.coeff);
        }
      } else {
        int new_index = term.index;
        new_index += aux_shift;
        result.add_term(
            variable<FieldT>(new_index),
            term.coeff);
      }
    } else {
      result.add_term(variable<FieldT>(term.index), term.coeff);
    }
  }

  return result;
}

void camlsnark_bn128_protoboard_renumber_and_append_constraints(
    protoboard<FieldT>* pb,
    r1cs_constraint_system<FieldT>* target,
    std::vector<linear_combination<FieldT>>* changes,
    int aux_shift
) {
  r1cs_constraint_system<FieldT> source = pb->get_constraint_system();
  int num_source_constraints = source.constraints.size();

  std::vector<linear_combination<FieldT>>& changesv = *changes;

  for (int i = 0; i < num_source_constraints; ++i) {
    r1cs_constraint<FieldT> c = source.constraints[i];
    c.a = camlsnark_bn128_linear_combination_renumber(c.a, *changes, aux_shift);
    c.b = camlsnark_bn128_linear_combination_renumber(c.b, *changes, aux_shift);
    c.c = camlsnark_bn128_linear_combination_renumber(c.c, *changes, aux_shift);

#ifdef DEBUG
    const std::string annotation = source.constraint_annotations[i];
    target->add_constraint(c, annotation);
#else
    target->add_constraint(c);
#endif
  }
}

void camlsnark_bn128_protoboard_set_variable(protoboard<FieldT>* pb, pb_variable<FieldT>* x, FieldT* y) {
  pb->val(*x) = *y;
}

FieldT* camlsnark_bn128_protoboard_get_variable(protoboard<FieldT>* pb, pb_variable<FieldT>* x) {
  return new FieldT(pb->val(*x));
}

void camlsnark_bn128_init_public_params() {
  ppT::init_public_params();
}

int camlsnark_bn128_field_size_in_bits() {
  auto n = FieldT::size_in_bits();
  return n;
}

libff::bigint<libff::bn128_r_limbs>* camlsnark_bn128_field_size() {
  libff::bigint<libff::bn128_r_limbs>* x = new libff::bigint<libff::bn128_r_limbs>(FieldT::field_char());
  return x;
}

variable<FieldT>* camlsnark_bn128_var_create(int i) {
  return new variable<FieldT>(i);
}

void camlsnark_bn128_var_delete(variable<FieldT>* v) {
  delete v;
}

size_t camlsnark_bn128_var_index(variable<FieldT>* v) {
  return v->index;
}

bool camlsnark_bn128_field_is_square(FieldT* x) {
  FieldT y = *x ^ FieldT::euler;
  return y == FieldT::one();
}

FieldT* camlsnark_bn128_field_sqrt(FieldT* x) {
  return new FieldT(x->sqrt());
}

FieldT* camlsnark_bn128_field_random() {
  return new FieldT(FieldT::random_element());
}

FieldT* camlsnark_bn128_field_of_int(int n) {
  return new FieldT(n);
}

FieldT* camlsnark_bn128_field_inv(FieldT* x) {
  return new FieldT(x->inverse());
}

FieldT* camlsnark_bn128_field_square(FieldT* x) {
  return new FieldT(x->squared());
}

FieldT* camlsnark_bn128_field_add(FieldT* x, FieldT* y) {
  return new FieldT(*x + *y);
}

FieldT* camlsnark_bn128_field_mul(FieldT* x, FieldT* y) {
  return new FieldT(*x * *y);
}

FieldT* camlsnark_bn128_field_sub(FieldT* x, FieldT* y) {
  return new FieldT(*x - *y);
}

FieldT* camlsnark_bn128_field_rng(int i) {
  return new FieldT(libff::SHA512_rng<FieldT>(i));
}

void camlsnark_bn128_field_delete(FieldT* f) {
  delete f;
}

void camlsnark_bn128_field_print(FieldT* f) {
  f->print();
}

// bigint bn128_r
libff::bigint<libff::bn128_r_limbs>* camlsnark_bn128_bigint_r_of_field(FieldT* x) {
  return new libff::bigint<libff::bn128_r_limbs>(x->as_bigint());
}

libff::bigint<libff::bn128_r_limbs>* camlsnark_bn128_bigint_r_of_decimal_string(char* x) {
  return new libff::bigint<libff::bn128_r_limbs>(x);
}

int camlsnark_bn128_bigint_r_num_limbs() {
  return libff::bn128_r_limbs;
}

char* camlsnark_bn128_bigint_r_to_data(libff::bigint<libff::bn128_r_limbs>* x) {
  return (char *) x->data;
}

libff::bigint<libff::bn128_r_limbs>* camlsnark_bn128_bigint_r_of_data(char* s) {
  libff::bigint<libff::bn128_r_limbs>* result = new libff::bigint<libff::bn128_r_limbs>();

  mp_limb_t* arr = (mp_limb_t *) s;

  for (int i = 0; i < libff::bn128_r_limbs; ++i) {
    result->data[i] = arr[i];
  }

  return result;
}

int camlsnark_bn128_bigint_r_bytes_per_limb() {
  return sizeof(mp_limb_t);
}

libff::bigint<libff::bn128_r_limbs>* camlsnark_bn128_bigint_r_div(
  libff::bigint<libff::bn128_r_limbs>* x,
  libff::bigint<libff::bn128_r_limbs>* y) {
  mpz_t n; mpz_init(n); x->to_mpz(n);
  mpz_t d; mpz_init(d); y->to_mpz(d);
  mpz_t q; mpz_init(q);

  mpz_fdiv_q(q, n, d);

  return new libff::bigint<libff::bn128_r_limbs>(q);
}

FieldT* camlsnark_bn128_bigint_r_to_field(libff::bigint<libff::bn128_r_limbs>* n) {
  return new FieldT(*n);
}

libff::bigint<libff::bn128_r_limbs>* camlsnark_bn128_bigint_r_of_numeral(const unsigned char* s, int s_length, int base) {
  libff::bigint<libff::bn128_r_limbs>* res = new libff::bigint<libff::bn128_r_limbs>();

  assert (base >= 2 && base <= 256);

  mp_size_t limbs_written = mpn_set_str(res->data, s, s_length, base);
  assert(limbs_written <= libff::bn128_r_limbs);

  return res;
}

int camlsnark_bn128_bigint_r_compare(
    libff::bigint<libff::bn128_r_limbs>* n1,
    libff::bigint<libff::bn128_r_limbs>* n2) {
  return mpn_cmp(n1->data, n2->data, libff::bn128_r_limbs);
}

bool camlsnark_bn128_bigint_r_test_bit(libff::bigint<libff::bn128_r_limbs>* n, int i) {
  return n->test_bit(i);
}

void camlsnark_bn128_bigint_r_delete(libff::bigint<libff::bn128_r_limbs>* n) {
  delete n;
}

void camlsnark_bn128_bigint_r_print(libff::bigint<libff::bn128_r_limbs>* n) {
  n->print();
}

std::vector<long>* camlsnark_bn128_bigint_r_find_wnaf(
    size_t window_size, libff::bigint<libff::bn128_r_limbs>* scalar) {
  return new std::vector<long>(libff::find_wnaf(window_size, *scalar));
}

// bigint bn128_q
bool camlsnark_bn128_bigint_q_test_bit(libff::bigint<libff::bn128_q_limbs>* n, int i) {
  return n->test_bit(i);
}

void camlsnark_bn128_bigint_q_delete(libff::bigint<libff::bn128_q_limbs>* n) {
  delete n;
}

void camlsnark_bn128_bigint_q_print(libff::bigint<libff::bn128_q_limbs>* n) {
  n->print();
}

std::vector<long>* camlsnark_bn128_bigint_q_find_wnaf(
    size_t window_size, libff::bigint<libff::bn128_q_limbs>* scalar) {
  return new std::vector<long>(libff::find_wnaf(window_size, *scalar));
}

bool camlsnark_bn128_field_equal(FieldT* x1, FieldT* x2) {
  return *x1 == *x2;
}

// begin linear_combination_vector
std::vector<linear_combination<FieldT>>* camlsnark_bn128_linear_combination_vector_create() {
  return new std::vector<linear_combination<FieldT>>();
}

void camlsnark_bn128_linear_combination_vector_delete(std::vector<linear_combination<FieldT>>* v) {
  delete v;
}

int camlsnark_bn128_linear_combination_vector_length(std::vector<linear_combination<FieldT>> *v) {
  return v->size();
}

void camlsnark_bn128_linear_combination_vector_emplace_back(std::vector<linear_combination<FieldT>>* v, linear_combination<FieldT>* x) {
  v->emplace_back(*x);
}

linear_combination<FieldT>* camlsnark_bn128_linear_combination_vector_get(std::vector<linear_combination<FieldT>>* v, int i) {
  linear_combination<FieldT> res = (*v)[i];
  return new linear_combination<FieldT>(res);
}
// end linear_combination_vector

linear_combination<FieldT>* camlsnark_bn128_linear_combination_create() {
  return new linear_combination<FieldT>();
}

void camlsnark_bn128_linear_combination_add_term(linear_combination<FieldT>* lc, FieldT* coeff, variable<FieldT>* v) {
  lc->add_term(*v, *coeff);
}

linear_combination<FieldT>* camlsnark_bn128_linear_combination_of_var(variable<FieldT>* v) {
  return new linear_combination<FieldT>(*v);
}

linear_combination<FieldT>* camlsnark_bn128_linear_combination_of_int(int n) {
  return new linear_combination<FieldT>(n);
}

linear_combination<FieldT>* camlsnark_bn128_linear_combination_of_field(FieldT* x) {
  return new linear_combination<FieldT>(*x);
}

void camlsnark_bn128_linear_combination_delete(linear_combination<FieldT>* lc) {
  delete lc;
}

void camlsnark_bn128_linear_combination_print(linear_combination<FieldT>* lc) {
  lc->print();
}

std::vector<linear_term<FieldT> >* camlsnark_bn128_linear_combination_terms(linear_combination<FieldT>* lc) {
  return new std::vector<linear_term<FieldT>>(lc->terms);
}

linear_combination<FieldT>* camlsnark_bn128_linear_combination_var_add(variable<FieldT>* v, linear_combination<FieldT>* other) {
  linear_combination<FieldT>* result = new linear_combination<FieldT>();

  result->add_term(*v);
  result->terms.insert(result->terms.begin(), other->terms.begin(), other->terms.end());
  return result;
}

linear_combination<FieldT>* camlsnark_bn128_linear_combination_var_sub(variable<FieldT>* v, linear_combination<FieldT>* other) {
  auto neg = -(*other);
  return camlsnark_bn128_linear_combination_var_add(v, &neg);
}

linear_combination<FieldT>* camlsnark_bn128_linear_combination_of_terms(std::vector<linear_term<FieldT>>* v) {
  return new linear_combination<FieldT>(*v);
}

linear_term<FieldT>* camlsnark_bn128_linear_combination_term_create(FieldT* x, variable<FieldT>* v) {
  return new linear_term<FieldT>(*v, *x);
}

void camlsnark_bn128_linear_combination_term_delete(linear_term<FieldT>* lt) {
  delete lt;
}

FieldT* camlsnark_bn128_linear_combination_term_coeff(linear_term<FieldT>* lt) {
  return new FieldT(lt->coeff);
}

int camlsnark_bn128_linear_combination_term_index(linear_term<FieldT>* lt) {
  return lt->index;
}

std::vector<linear_term<FieldT>>* camlsnark_bn128_linear_combination_term_vector_create() {
  return new std::vector<linear_term<FieldT>>();
}

void camlsnark_bn128_linear_combination_term_vector_delete(std::vector<linear_term<FieldT>>* v) {
  delete v;
}

int camlsnark_bn128_linear_combination_term_vector_length(std::vector<linear_term<FieldT>> *v) {
  return v->size();
}

// Not too sure what's going on here memory-wise...
void camlsnark_bn128_linear_combination_term_vector_emplace_back(std::vector<linear_term<FieldT>>* v, linear_term<FieldT>* x) {
  v->emplace_back(*x);
}

linear_term<FieldT>* camlsnark_bn128_linear_combination_term_vector_get(std::vector<linear_term<FieldT>>* v, int i) {
  linear_term<FieldT> res = (*v)[i];
  return new linear_term<FieldT>(res);
}

r1cs_constraint<FieldT>* camlsnark_bn128_r1cs_constraint_create(
    linear_combination<FieldT>* a,
    linear_combination<FieldT>* b,
    linear_combination<FieldT>* c) {
  return new r1cs_constraint<FieldT>(*a, *b, *c);
}

void camlsnark_bn128_r1cs_constraint_delete(r1cs_constraint<FieldT>* c) {
  delete c;
}

void camlsnark_bn128_r1cs_constraint_set_is_square(r1cs_constraint<FieldT>* c, bool is_square) {
  c->is_square = is_square;
}

r1cs_constraint_system<FieldT>* camlsnark_bn128_r1cs_constraint_system_create() {
  return new r1cs_constraint_system<FieldT>();
}

void camlsnark_bn128_r1cs_constraint_system_clear(r1cs_constraint_system<FieldT>* sys) {
  sys->primary_input_size = 0;
  sys->auxiliary_input_size = 0;
  sys->num_square_constraints = 0;
  sys->constraints.clear();
}

void camlsnark_bn128_linear_combination_update_digest(
    linear_combination<FieldT>& lc,
    MD5_CTX* ctx) {
  long coeff_size_in_bytes = libff::bn128_r_limbs * sizeof(mp_limb_t);

  std::vector<linear_term<FieldT>>& terms = lc.terms;
  for (size_t i = 0; i < terms.size(); ++i) {
    size_t index = terms[i].index;
    FieldT coeff = terms[i].coeff;
    MD5_Update(ctx, (void*) &index, (sizeof index));
    MD5_Update(ctx, coeff.as_bigint().data, coeff_size_in_bytes);
  }
}

std::string* camlsnark_bn128_r1cs_constraint_system_digest(
    r1cs_constraint_system<FieldT>* sys) {
  MD5_CTX ctx;
  MD5_Init(&ctx);

  std::vector<r1cs_constraint<FieldT>>& cs = sys->constraints;

  for (size_t i = 0; i < cs.size(); ++i) {
    r1cs_constraint<FieldT> c = cs[i];
    camlsnark_bn128_linear_combination_update_digest(c.a, &ctx);
    camlsnark_bn128_linear_combination_update_digest(c.b, &ctx);
    camlsnark_bn128_linear_combination_update_digest(c.c, &ctx);
  }

  std::string* result = new std::string(MD5_DIGEST_LENGTH, '\0');
  MD5_Final((unsigned char *) result->c_str(), &ctx);
  return result;
}

bool camlsnark_bn128_r1cs_constraint_system_is_satisfied(
    r1cs_constraint_system<FieldT>* sys,
    const r1cs_primary_input<FieldT>* primary_input,
    const r1cs_auxiliary_input<FieldT>* auxiliary_input
    ) {
  return sys->is_satisfied(*primary_input, *auxiliary_input);
}

bool camlsnark_bn128_linear_combination_check(
    size_t total_input_size,
    linear_combination<FieldT>& lc) {
  std::vector<linear_term<FieldT>>& terms = lc.terms;
  for (size_t i = 0; i < terms.size(); ++i) {
    if (terms[i].index > total_input_size) {
      return false;
    }
  }
  return true;
}

bool camlsnark_bn128_r1cs_constraint_system_check(r1cs_constraint_system<FieldT>* sys) {
  std::vector<r1cs_constraint<FieldT>>& cs = sys->constraints;
  size_t total_input_size = sys->num_variables();
  for (size_t i = 0; i < cs.size(); ++i) {
    r1cs_constraint<FieldT> c = cs[i];
    if (!camlsnark_bn128_linear_combination_check(total_input_size, c.a)) { return false; }
    if (!camlsnark_bn128_linear_combination_check(total_input_size, c.b)) { return false; }
    if (!camlsnark_bn128_linear_combination_check(total_input_size, c.c)) { return false; }
  }
  return true;
}

void camlsnark_bn128_r1cs_constraint_system_delete(r1cs_constraint_system<FieldT>* sys) {
  delete sys;
}

void camlsnark_bn128_r1cs_constraint_system_report_statistics(r1cs_constraint_system<FieldT>* sys) {
  sys->report_linear_constraint_statistics();
}

void camlsnark_bn128_r1cs_constraint_system_add_constraint(
    r1cs_constraint_system<FieldT>* sys, 
    r1cs_constraint<FieldT>* c) {
  sys->add_constraint(*c);
}

void camlsnark_bn128_r1cs_constraint_system_add_constraint_with_annotation(
    r1cs_constraint_system<FieldT>* sys, 
    r1cs_constraint<FieldT>* c,
    char* s) {
  std::string str(s);
  sys->add_constraint(*c, str);
}

void camlsnark_bn128_r1cs_constraint_system_set_primary_input_size(
    r1cs_constraint_system<FieldT>* sys, 
    int n) {
  sys->primary_input_size = n;
}

void camlsnark_bn128_r1cs_constraint_system_set_auxiliary_input_size(
    r1cs_constraint_system<FieldT>* sys, 
    int n) {
  sys->auxiliary_input_size = n;
}

int camlsnark_bn128_r1cs_constraint_system_get_primary_input_size(
    r1cs_constraint_system<FieldT>* sys) {
  return sys->primary_input_size;
}

int camlsnark_bn128_r1cs_constraint_system_get_auxiliary_input_size(
    r1cs_constraint_system<FieldT>* sys) {
  return sys->auxiliary_input_size;
}

std::vector<FieldT>* camlsnark_bn128_field_vector_create() {
  return new std::vector<FieldT>();
}

int camlsnark_bn128_field_vector_length(std::vector<FieldT> *v) {
  return v->size();
}

// Not too sure what's going on here memory-wise...
void camlsnark_bn128_field_vector_emplace_back(std::vector<FieldT>* v, FieldT* x) {
  v->emplace_back(*x);
}

FieldT* camlsnark_bn128_field_vector_get(std::vector<FieldT>* v, int i) {
  FieldT res = (*v)[i];
  return new FieldT(res);
}

void camlsnark_bn128_field_vector_delete(std::vector<FieldT>* v) {
  delete v;
}

// Begin ppzksnark specific code
r1cs_constraint_system<FieldT>* camlsnark_bn128_proving_key_r1cs_constraint_system(
    r1cs_ppzksnark_proving_key<ppT>* pk) {
  return &pk->constraint_system;
}

std::string* camlsnark_bn128_proving_key_to_string(r1cs_ppzksnark_proving_key<ppT>* pk) {
  std::stringstream stream;
  stream << *pk;
  return new std::string(stream.str());
}

r1cs_ppzksnark_proving_key<ppT>* camlsnark_bn128_proving_key_of_string(std::string* s) {
  r1cs_ppzksnark_proving_key<ppT>*  pk = new r1cs_ppzksnark_proving_key<ppT>();
  std::stringstream stream(*s);
  stream >> *pk;
  return pk;
}

void camlsnark_bn128_proving_key_delete(r1cs_ppzksnark_proving_key<ppT>* pk) {
  delete pk;
}

void camlsnark_bn128_verification_key_delete(r1cs_ppzksnark_verification_key<ppT>* vk) {
  delete vk;
}

int camlsnark_bn128_verification_key_size_in_bits(
    r1cs_ppzksnark_verification_key<ppT>* vk
) {
  return vk->size_in_bits();
}

std::string* camlsnark_bn128_verification_key_to_string(r1cs_ppzksnark_verification_key<ppT>* vk) {
  std::stringstream stream;
  stream << *vk;
  return new std::string(stream.str());
}

r1cs_ppzksnark_verification_key<ppT>* camlsnark_bn128_verification_key_of_string(std::string* s) {
  r1cs_ppzksnark_verification_key<ppT>*  vk = new r1cs_ppzksnark_verification_key<ppT>();
  std::stringstream stream(*s);
  stream >> *vk;
  return vk;
}

r1cs_ppzksnark_proving_key<ppT>* camlsnark_bn128_keypair_pk(r1cs_ppzksnark_keypair<ppT>* keypair) {
  return new r1cs_ppzksnark_proving_key<ppT>(keypair->pk);
}

r1cs_ppzksnark_verification_key<ppT>* camlsnark_bn128_keypair_vk(r1cs_ppzksnark_keypair<ppT>* keypair) {
  return new r1cs_ppzksnark_verification_key<ppT>(keypair->vk);
}

void camlsnark_bn128_keypair_delete(r1cs_ppzksnark_keypair<ppT>* keypair) {
  delete keypair;
}

r1cs_ppzksnark_keypair<ppT>* camlsnark_bn128_keypair_create(
    r1cs_constraint_system<FieldT>* sys) {
  r1cs_ppzksnark_keypair<ppT> res = r1cs_ppzksnark_generator<ppT>(*sys);
  return new r1cs_ppzksnark_keypair<ppT>(res);
}

std::string* camlsnark_bn128_proof_to_string(
    r1cs_ppzksnark_proof<ppT>* p) {
  std::stringstream stream;
  stream << *p;
  return new std::string(stream.str());
}

r1cs_ppzksnark_proof<ppT>* camlsnark_bn128_proof_of_string(std::string* s) {
  r1cs_ppzksnark_proof<ppT>*  p = new r1cs_ppzksnark_proof<ppT>();
  std::stringstream stream(*s);
  stream >> *p;
  return p;
}

r1cs_ppzksnark_proof<ppT>* camlsnark_bn128_proof_create(
    r1cs_ppzksnark_proving_key<ppT>* key,
    std::vector<FieldT>* primary_input,
    std::vector<FieldT>* auxiliary_input) {
  auto res = r1cs_ppzksnark_prover(*key, *primary_input, *auxiliary_input);
  return new r1cs_ppzksnark_proof<ppT>(res);
}

void camlsnark_bn128_proof_delete(r1cs_ppzksnark_proof<ppT>* proof) {
  delete proof;
}

bool camlsnark_bn128_proof_verify(
    r1cs_ppzksnark_proof<ppT>* proof,
    r1cs_ppzksnark_verification_key<ppT>* key,
    std::vector<FieldT>* primary_input) {
  return r1cs_ppzksnark_verifier_weak_IC(*key, *primary_input, *proof);
}
// End ppzksnark specific code

// Begin Groth-Maller specific code
r1cs_constraint_system<FieldT>* camlsnark_bn128_gm_proving_key_r1cs_constraint_system(
    r1cs_se_ppzksnark_proving_key<ppT>* pk) {
  return &pk->constraint_system;
}

std::string* camlsnark_bn128_gm_proving_key_to_string(r1cs_se_ppzksnark_proving_key<ppT>* pk) {
  std::stringstream stream;
  stream << *pk;
  return new std::string(stream.str());
}

r1cs_se_ppzksnark_proving_key<ppT>* camlsnark_bn128_gm_proving_key_of_string(std::string* s) {
  r1cs_se_ppzksnark_proving_key<ppT>*  pk = new r1cs_se_ppzksnark_proving_key<ppT>();
  std::stringstream stream(*s);
  stream >> *pk;
  return pk;
}

void camlsnark_bn128_gm_proving_key_delete(r1cs_se_ppzksnark_proving_key<ppT>* pk) {
  delete pk;
}

void camlsnark_bn128_gm_verification_key_delete(r1cs_se_ppzksnark_verification_key<ppT>* vk) {
  delete vk;
}

int camlsnark_bn128_gm_verification_key_size_in_bits(
    r1cs_se_ppzksnark_verification_key<ppT>* vk
) {
  return vk->size_in_bits();
}

libff::G2<ppT>* 
camlsnark_bn128_gm_verification_key_h(
    r1cs_se_ppzksnark_verification_key<ppT>* vk
) {
  return new libff::G2<ppT>(vk->H);
}

libff::G1<ppT>* 
camlsnark_bn128_gm_verification_key_g_alpha(
    r1cs_se_ppzksnark_verification_key<ppT>* vk
) {
  return new libff::G1<ppT>(vk->G_alpha);
}

libff::G2<ppT>* 
camlsnark_bn128_gm_verification_key_h_beta(
    r1cs_se_ppzksnark_verification_key<ppT>* vk
) {
  return new libff::G2<ppT>(vk->H_beta);
}

libff::G1<ppT>* 
camlsnark_bn128_gm_verification_key_g_gamma (
    r1cs_se_ppzksnark_verification_key<ppT>* vk
) {
  return new libff::G1<ppT>(vk->G_gamma);
}

libff::G2<ppT>* 
camlsnark_bn128_gm_verification_key_h_gamma (
    r1cs_se_ppzksnark_verification_key<ppT>* vk
) {
  return new libff::G2<ppT>(vk->H_gamma);
}

std::vector< libff::G1<ppT> >*
camlsnark_bn128_gm_verification_key_query(
    r1cs_se_ppzksnark_verification_key<ppT> *vk)
{
    return new std::vector<libff::G1<ppT>>(vk->query);
}

std::string* camlsnark_bn128_gm_verification_key_to_string(r1cs_se_ppzksnark_verification_key<ppT>* vk) {
  std::stringstream stream;
  stream << *vk;
  return new std::string(stream.str());
}

r1cs_se_ppzksnark_verification_key<ppT>* camlsnark_bn128_gm_verification_key_of_string(std::string* s) {
  r1cs_se_ppzksnark_verification_key<ppT>*  vk = new r1cs_se_ppzksnark_verification_key<ppT>();
  std::stringstream stream(*s);
  stream >> *vk;
  return vk;
}

r1cs_se_ppzksnark_proving_key<ppT>* camlsnark_bn128_gm_keypair_pk(r1cs_se_ppzksnark_keypair<ppT>* keypair) {
  return new r1cs_se_ppzksnark_proving_key<ppT>(keypair->pk);
}

r1cs_se_ppzksnark_verification_key<ppT>* camlsnark_bn128_gm_keypair_vk(r1cs_se_ppzksnark_keypair<ppT>* keypair) {
  return new r1cs_se_ppzksnark_verification_key<ppT>(keypair->vk);
}

void camlsnark_bn128_gm_keypair_delete(r1cs_se_ppzksnark_keypair<ppT>* keypair) {
  delete keypair;
}

r1cs_se_ppzksnark_keypair<ppT>* camlsnark_bn128_gm_keypair_create(
    r1cs_constraint_system<FieldT>* sys) {
  r1cs_se_ppzksnark_keypair<ppT> res = r1cs_se_ppzksnark_generator<ppT>(*sys);
  return new r1cs_se_ppzksnark_keypair<ppT>(res);
}

std::string* camlsnark_bn128_gm_proof_to_string(
    r1cs_se_ppzksnark_proof<ppT>* p) {
  std::stringstream stream;
  stream << *p;
  return new std::string(stream.str());
}

r1cs_se_ppzksnark_proof<ppT>* camlsnark_bn128_gm_proof_of_string(std::string* s) {
  r1cs_se_ppzksnark_proof<ppT>*  p = new r1cs_se_ppzksnark_proof<ppT>();
  std::stringstream stream(*s);
  stream >> *p;
  return p;
}

r1cs_se_ppzksnark_proof<ppT>* camlsnark_bn128_gm_proof_create(
    r1cs_se_ppzksnark_proving_key<ppT>* key,
    std::vector<FieldT>* primary_input,
    std::vector<FieldT>* auxiliary_input) {
  auto res = r1cs_se_ppzksnark_prover(*key, *primary_input, *auxiliary_input);
  return new r1cs_se_ppzksnark_proof<ppT>(res);
}

void camlsnark_bn128_gm_proof_delete(r1cs_se_ppzksnark_proof<ppT>* proof) {
  delete proof;
}

bool camlsnark_bn128_gm_proof_verify(
    r1cs_se_ppzksnark_proof<ppT>* proof,
    r1cs_se_ppzksnark_verification_key<ppT>* key,
    std::vector<FieldT>* primary_input) {
  return r1cs_se_ppzksnark_verifier_weak_IC(*key, *primary_input, *proof);
}

libff::G1<ppT>* camlsnark_bn128_gm_proof_a(r1cs_se_ppzksnark_proof<ppT>* proof) {
  return new libff::G1<ppT>(proof->A);
}

libff::G2<ppT>* camlsnark_bn128_gm_proof_b(r1cs_se_ppzksnark_proof<ppT>* proof) {
  return new libff::G2<ppT>(proof->B);
}

libff::G1<ppT>* camlsnark_bn128_gm_proof_c(r1cs_se_ppzksnark_proof<ppT>* proof) {
  return new libff::G1<ppT>(proof->C);
}

// End Groth-Maller specific code

// begin SHA gadget code
void camlsnark_bn128_digest_variable_delete(
    digest_variable<FieldT>* digest) {
  delete digest;
}

digest_variable<FieldT>* camlsnark_bn128_digest_variable_create(
    protoboard<FieldT>* pb, int digest_size) {
  return new digest_variable<FieldT>(*pb, digest_size, "digest_variable_create");
}

pb_variable_array<FieldT>* camlsnark_bn128_digest_variable_bits(
    digest_variable<FieldT>* digest) {
  return new pb_variable_array<FieldT>(digest->bits);
}

void camlsnark_bn128_sha256_compression_function_gadget_delete(
    sha256_compression_function_gadget<FieldT>* g) {
  delete g;
}

sha256_compression_function_gadget<FieldT>*
camlsnark_bn128_sha256_compression_function_gadget_create(
    protoboard<FieldT>* pb,
    pb_variable_array<FieldT>* prev_output,
    pb_variable_array<FieldT>* new_block,
    digest_variable<FieldT>* output) {
  return new sha256_compression_function_gadget<FieldT>(
      *pb,
      pb_linear_combination_array<FieldT>(*prev_output),
      *new_block,
      *output,
      "sha256_compression_function_gadget_create");
}

void camlsnark_bn128_sha256_compression_function_gadget_generate_r1cs_constraints(
  sha256_compression_function_gadget<FieldT>* g) {
  g->generate_r1cs_constraints();
}

void camlsnark_bn128_sha256_compression_function_gadget_generate_r1cs_witness(
  sha256_compression_function_gadget<FieldT>* g) {
  g->generate_r1cs_witness();
}

}
