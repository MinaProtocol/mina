/** @file
 *****************************************************************************
 Implementation of PublicParams for Fp field arithmetic
 *****************************************************************************
 * @author     This file is part of libsnark, developed by SCIPR Lab
 *             and contributors (see AUTHORS).
 * @copyright  MIT license (see LICENSE file)
 *****************************************************************************/

#include <cassert>
#include <vector>

#include <libsnark/gadgetlib2/pp.hpp>

namespace gadgetlib2 {

PublicParams::PublicParams(const std::size_t log_p) : log_p(log_p) {}

Fp PublicParams::getFp(long x) const {
    return Fp(x);
}

PublicParams::~PublicParams() {}

PublicParams initPublicParamsFromDefaultPp() {
    libff::default_ec_pp::init_public_params();
    const std::size_t log_p = libff::Fr<libff::default_ec_pp>::size_in_bits();
    return PublicParams(log_p);
}

} // namespace gadgetlib2
