%module BN254

%include "std_string.i"
%include "std_except.i"

%{
#include "bn254_if.hpp"
%}

%typemap(javacode) Mpz %{
  public boolean equals(Object obj) {
    if (this == obj) return true;
    if (!(obj instanceof $javaclassname)) return false;
    return equals(($javaclassname)obj);
  }
%}

%typemap(javacode) Fp %{
  public boolean equals(Object obj) {
    if (this == obj) return true;
    if (!(obj instanceof $javaclassname)) return false;
    return equals(($javaclassname)obj);
  }
%}

%typemap(javacode) Fp2 %{
  public boolean equals(Object obj) {
    if (this == obj) return true;
    if (!(obj instanceof $javaclassname)) return false;
    return equals(($javaclassname)obj);
  }
%}

%typemap(javacode) Fp12 %{
  public boolean equals(Object obj) {
    if (this == obj) return true;
    if (!(obj instanceof $javaclassname)) return false;
    return equals(($javaclassname)obj);
  }
%}

%typemap(javacode) Ec1 %{
  public boolean equals(Object obj) {
    if (this == obj) return true;
    if (!(obj instanceof $javaclassname)) return false;
    return equals(($javaclassname)obj);
  }
%}

%typemap(javacode) Ec2 %{
  public boolean equals(Object obj) {
    if (this == obj) return true;
    if (!(obj instanceof $javaclassname)) return false;
    return equals(($javaclassname)obj);
  }
%}

%include "bn254_if.hpp"

