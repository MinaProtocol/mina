/** @file
 *****************************************************************************

 Implementation of exceptions.

 *****************************************************************************
 * @author     This file is part of libfqfft, developed by SCIPR Lab
 *             and contributors (see AUTHORS).
 * @copyright  MIT license (see LICENSE file)
 *****************************************************************************/

#ifndef EXCEPTIONS_HPP_
#define EXCEPTIONS_HPP_

#include <exception>
#include <iostream>
#include <string>

namespace libfqfft {

class DomainSizeException
{
public:
    DomainSizeException(std::string error): _error(error) {}
    const char* what() const
	{
	    return _error.c_str();
	}
private:
    std::string _error;
};

class InvalidSizeException
{
public:
    InvalidSizeException(std::string error): _error(error) {}
    const char* what() const
	{
	    return _error.c_str();
	}
private:
    std::string _error;
};

} //libfqfft

#endif // EXCEPTIONS_HPP_