/** @file
 *****************************************************************************

 Implementation of functionality that is shared among MNT curves.

 See mnt46_common.hpp .

 *****************************************************************************
 * @author     This file is part of libff, developed by SCIPR Lab
 *             and contributors (see AUTHORS).
 * @copyright  MIT license (see LICENSE file)
 *****************************************************************************/

#include <libff/algebra/curves/mnt_128/mnt46128_common.hpp>

namespace libff {

bigint<mnt46128_A_limbs> mnt46128_modulus_A;
bigint<mnt46128_B_limbs> mnt46128_modulus_B;

} // libff
