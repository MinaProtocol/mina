/** @file
 *****************************************************************************

 This file defines default_r1cs_se_ppzksnark_pp based on the elliptic curve
 choice selected in ec_pp.hpp.

 *****************************************************************************
 * @author     This file is part of libsnark, developed by SCIPR Lab
 *             and contributors (see AUTHORS).
 * @copyright  MIT license (see LICENSE file)
 *****************************************************************************/

#ifndef R1CS_SE_PPZKSNARK_PP_HPP_
#define R1CS_SE_PPZKSNARK_PP_HPP_

#include <libff/common/default_types/ec_pp.hpp>

namespace libsnark {
typedef libff::default_ec_pp default_r1cs_se_ppzksnark_pp;
} // libsnark

#endif // R1CS_SE_PPZKSNARK_PP_HPP_
