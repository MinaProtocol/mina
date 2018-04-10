/** @file
 *****************************************************************************
 * @author     This file is part of libff, developed by SCIPR Lab
 *             and contributors (see AUTHORS).
 * @copyright  MIT license (see LICENSE file)
 *****************************************************************************/

#ifndef CURVE_UTILS_TCC_
#define CURVE_UTILS_TCC_

namespace libff {

template<typename GroupT, mp_size_t m>
GroupT scalar_mul(const GroupT &base, const bigint<m> &scalar)
{
    GroupT result = GroupT::zero();

    bool found_one = false;
    for (long i = static_cast<long>(scalar.max_bits() - 1); i >= 0; --i)
    {
        if (found_one)
        {
            result = result.dbl();
        }

        if (scalar.test_bit(i))
        {
            found_one = true;
            result = result + base;
        }
    }

    return result;
}

} // libff
#endif // CURVE_UTILS_TCC_
