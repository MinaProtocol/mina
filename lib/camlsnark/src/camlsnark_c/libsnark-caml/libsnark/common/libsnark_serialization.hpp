/** @file
 *****************************************************************************

 Temporary import serialization operators from libff in libsnark namspace;

 *****************************************************************************
 * @author     This file is part of libsnark, developed by SCIPR Lab
 *             and contributors (see AUTHORS).
 * @copyright  MIT license (see LICENSE file)
 *****************************************************************************/

#ifndef LIBSNARK_SERIALIZATION_HPP_
#define LIBSNARK_SERIALIZATION_HPP_

#include <libff/common/serialization.hpp>

namespace libsnark {
    using libff::consume_newline;
    using libff::consume_OUTPUT_NEWLINE;
    using libff::consume_OUTPUT_SEPARATOR;

    using libff::output_bool;
    using libff::input_bool;

    using libff::input_bool_vector;
    using libff::output_bool_vector;
    using libff::operator<<;
    using libff::operator>>;
}

#endif // LIBSNARK_SERIALIZATION_HPP_
