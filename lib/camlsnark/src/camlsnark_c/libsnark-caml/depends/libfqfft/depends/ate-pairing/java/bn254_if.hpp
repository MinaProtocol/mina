#pragma once
/**
	@file
	@brief api for Java
	@author herumi
	@note modified new BSD license
	http://opensource.org/licenses/BSD-3-Clause
*/
#ifndef MIE_ATE_USE_GMP
	#define MIE_ATE_USE_GMP
#endif
#include "bn.h"

inline void SystemInit() throw(std::exception)
{
	::bn::Param::init();
}

class Fp2;
class Fp12;
class Ec1;
class Ec2;

class Mpz {
	mpz_class self_;
	friend class Fp;
	friend class Fp2;
	friend class Fp12;
	friend class Ec1;
	friend class Ec2;
public:
	Mpz() {}
	Mpz(const Mpz& x) : self_(x.self_) {}
	Mpz(int x) throw(std::exception) : self_(x) {}
	Mpz(const std::string& str) throw(std::exception)
	{
		set(str);
	}
	void set(int x) throw(std::exception) { self_ = x; }
	void set(const std::string& str) throw(std::exception)
	{
		self_.set_str(str, 0);
	}
	std::string toString() const throw(std::exception)
	{
		return self_.get_str();
	}
	bool equals(const Mpz& rhs) const { return self_ == rhs.self_; }
	int compareTo(const Mpz& rhs) const { return mpz_cmp(self_.get_mpz_t(), rhs.self_.get_mpz_t()); }
	void add(const Mpz& rhs) throw(std::exception) { self_ += rhs.self_; }
	void sub(const Mpz& rhs) throw(std::exception) { self_ -= rhs.self_; }
	void mul(const Mpz& rhs) throw(std::exception) { self_ *= rhs.self_; }
	void mod(const Mpz& rhs) throw(std::exception) { self_ %= rhs.self_; }
};

class Fp {
	::bn::Fp self_;
	friend class Fp2;
	friend class Ec1;
public:
	Fp() {}
	Fp(const Fp& x) : self_(x.self_) {}
	Fp(int x) : self_(x) {}
	Fp(const std::string& str) throw(std::exception)
	{
		self_.set(str);
	}
	void set(int x) { self_ = x; }
	void set(const std::string& str) throw(std::exception)
	{
		self_.set(str);
	}
	std::string toString() const throw(std::exception)
	{
		return self_.toString();
	}
	bool equals(const Fp& rhs) const { return self_ == rhs.self_; }
	void add(const Fp& rhs) throw(std::exception) { self_ += rhs.self_; }
	void sub(const Fp& rhs) throw(std::exception) { self_ -= rhs.self_; }
	void mul(const Fp& rhs) throw(std::exception) { self_ *= rhs.self_; }
	void power(const Mpz& x)
	{
		self_ = mie::power(self_, x.self_);
	}
};

class Fp2 {
	::bn::Fp2 self_;
	friend class Ec2;
public:
	Fp2() {}
	Fp2(const Fp2& x) : self_(x.self_) {}
	Fp2(int a) : self_(a) {}
	Fp2(int a, int b) : self_(a, b) {}
	Fp2(const Fp& a, const Fp& b) throw(std::exception)
		: self_(a.self_, b.self_)
	{
	}
	Fp2(const std::string& a, const std::string& b) throw(std::exception)
		: self_(Fp(a).self_, Fp(b).self_)
	{
	}
	Fp& getA() { return *reinterpret_cast<Fp*>(&self_.a_); }
	Fp& getB() { return *reinterpret_cast<Fp*>(&self_.b_); }
	void set(const std::string& str) throw(std::exception)
	{
		self_.set(str);
	}
	std::string toString() const throw(std::exception)
	{
		return self_.toString();
	}
	bool equals(const Fp2& rhs) const { return self_ == rhs.self_; }
	void add(const Fp2& rhs) throw(std::exception) { self_ += rhs.self_; }
	void sub(const Fp2& rhs) throw(std::exception) { self_ -= rhs.self_; }
	void mul(const Fp2& rhs) throw(std::exception) { self_ *= rhs.self_; }
	void power(const Mpz& x)
	{
		self_ = mie::power(self_, x.self_);
	}
};

class Fp12 {
	::bn::Fp12 self_;
public:
	Fp12() {}
	Fp12(const Fp12& x) : self_(x.self_) {}
	Fp12(int x) : self_(x) {}
	void set(const std::string& str) throw(std::exception)
	{
		std::istringstream iss(str);
		iss >> self_;
	}
	std::string toString() const throw(std::exception)
	{
		std::ostringstream oss;
		oss << self_;
		return oss.str();
	}
	bool equals(const Fp12& rhs) const { return self_ == rhs.self_; }
	void add(const Fp12& rhs) throw(std::exception) { self_ += rhs.self_; }
	void sub(const Fp12& rhs) throw(std::exception) { self_ -= rhs.self_; }
	void mul(const Fp12& rhs) throw(std::exception) { self_ *= rhs.self_; }
	void pairing(const Ec2& ec2, const Ec1& ec1);
	void power(const Mpz& x)
	{
		self_ = mie::power(self_, x.self_);
	}
};

class Ec1 {
	::bn::Ec1 self_;
	friend class Fp12;
public:
	Ec1() { self_.clear(); }
	Ec1(const Ec1& x) : self_(x.self_) {}
	Ec1(const Fp& x, const Fp& y) throw(std::exception)
	{
		set(x, y);
	}
	Ec1(const Fp& x, const Fp& y, const Fp& z) throw(std::exception)
	{
		set(x, y, z);
	}
	bool isValid() const { return self_.isValid(); }
	void set(const Fp& x, const Fp& y) throw(std::exception)
	{
		self_.set(x.self_, y.self_);
	}
	void set(const Fp& x, const Fp& y, const Fp& z) throw(std::exception)
	{
		self_.set(x.self_, y.self_, z.self_);
	}
	void set(const std::string& str) throw(std::exception)
	{
		std::istringstream iss(str);
		iss >> self_;
	}
	std::string toString() const throw(std::exception)
	{
		std::ostringstream oss;
		oss << self_;
		return oss.str();
	}
	bool equals(const Ec1& rhs) const { return self_ == rhs.self_; }
	bool isZero() const { return self_.isZero(); }
	void clear() { self_.clear(); }
	void dbl() { ::bn::Ec1::dbl(self_, self_); }
	void neg() { ::bn::Ec1::neg(self_, self_); }
	void add(const Ec1& rhs) { ::bn::Ec1::add(self_, self_, rhs.self_); }
	void sub(const Ec1& rhs) { ::bn::Ec1::sub(self_, self_, rhs.self_); }
	void mul(const Mpz& rhs) { ::bn::Ec1::mul(self_, self_, rhs.self_); }
	Fp& getX() { return *reinterpret_cast<Fp*>(&self_.p[0]); }
	Fp& getY() { return *reinterpret_cast<Fp*>(&self_.p[1]); }
	Fp& getZ() { return *reinterpret_cast<Fp*>(&self_.p[2]); }
};

class Ec2 {
	::bn::Ec2 self_;
	friend class Fp12;
public:
	Ec2() {}
	Ec2(const Ec2& x) : self_(x.self_) {}
	Ec2(const Fp2& x, const Fp2& y) throw(std::exception)
	{
		set(x, y);
	}
	Ec2(const Fp2& x, const Fp2& y, const Fp2& z) throw(std::exception)
	{
		set(x, y, z);
	}
	bool isValid() const { return self_.isValid(); }
	void set(const Fp2& x, const Fp2& y) throw(std::exception)
	{
		self_.set(x.self_, y.self_);
	}
	void set(const Fp2& x, const Fp2& y, const Fp2& z) throw(std::exception)
	{
		self_.set(x.self_, y.self_, z.self_);
	}
	void set(const std::string& str) throw(std::exception)
	{
		std::istringstream iss(str);
		iss >> self_;
	}
	std::string toString() const throw(std::exception)
	{
		std::ostringstream oss;
		oss << self_;
		return oss.str();
	}
	bool equals(const Ec2& rhs) const { return self_ == rhs.self_; }
	bool isZero() const { return self_.isZero(); }
	void clear() { self_.clear(); }
	void dbl() { ::bn::Ec2::dbl(self_, self_); }
	void neg() { ::bn::Ec2::neg(self_, self_); }
	void add(const Ec2& rhs) { ::bn::Ec2::add(self_, self_, rhs.self_); }
	void sub(const Ec2& rhs) { ::bn::Ec2::sub(self_, self_, rhs.self_); }
	void mul(const Mpz& rhs) { ::bn::Ec2::mul(self_, self_, rhs.self_); }
	Fp2& getX() { return *reinterpret_cast<Fp2*>(&self_.p[0]); }
	Fp2& getY() { return *reinterpret_cast<Fp2*>(&self_.p[1]); }
	Fp2& getZ() { return *reinterpret_cast<Fp2*>(&self_.p[2]); }
};

void Fp12::pairing(const Ec2& ec2, const Ec1& ec1)
{
	::bn::opt_atePairing(self_, ec2.self_, ec1.self_);
}

inline const Mpz& GetParamR()
{
	static Mpz r("16798108731015832284940804142231733909759579603404752749028378864165570215949");
	return r;
}

#ifdef _MSC_VER
#if _MSC_VER == 1900
#ifdef _DEBUG
#pragma comment(lib, "14/mpird.lib")
#pragma comment(lib, "14/mpirxxd.lib")
#else
#pragma comment(lib, "14/mpir.lib")
#pragma comment(lib, "14/mpirxx.lib")
#endif
#elif _MSC_VER == 1800
#ifdef _DEBUG
#pragma comment(lib, "12/mpird.lib")
#pragma comment(lib, "12/mpirxxd.lib")
#else
#pragma comment(lib, "12/mpir.lib")
#pragma comment(lib, "12/mpirxx.lib")
#endif
#else
#ifdef _DEBUG
#pragma comment(lib, "mpird.lib")
#pragma comment(lib, "mpirxxd.lib")
#else
#pragma comment(lib, "mpir.lib")
#pragma comment(lib, "mpirxx.lib")
#endif
#endif
#endif
