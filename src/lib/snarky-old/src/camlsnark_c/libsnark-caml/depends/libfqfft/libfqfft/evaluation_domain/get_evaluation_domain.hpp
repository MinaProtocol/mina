/** @file
 *****************************************************************************

 A convenience method for choosing an evaluation domain

 Returns an evaluation domain object in which the domain S has size
 |S| >= min_size.
 The function chooses from different supported domains, depending on min_size.

 *****************************************************************************
 * @author     This file is part of libfqfft, developed by SCIPR Lab
 *             and contributors (see AUTHORS).
 * @copyright  MIT license (see LICENSE file)
 *****************************************************************************/

#ifndef GET_EVALUATION_DOMAIN_HPP_
#define GET_EVALUATION_DOMAIN_HPP_

#include <memory>

#include <libfqfft/evaluation_domain/evaluation_domain.hpp>

namespace libfqfft {

template<typename FieldT>
std::shared_ptr<evaluation_domain<FieldT> > get_evaluation_domain(const size_t min_size);

} // libfqfft

#include <libfqfft/evaluation_domain/get_evaluation_domain.tcc>

#endif // GET_EVALUATION_DOMAIN_HPP_
