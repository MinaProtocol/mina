#ifndef MIE_ATE_UTIL_H_
#define MIE_ATE_UTIL_H_

#ifdef _WIN32

#include <time.h>

static inline double GetCurrTime()
{
	return clock() / double(CLOCKS_PER_SEC);
}
#else

#include <sys/time.h>
#include <stdio.h>

static inline double GetCurrTime()
{
	struct timeval tv;
	gettimeofday(&tv, NULL);
	return tv.tv_sec + (double) tv.tv_usec * 1e-6;
}
#endif

#endif
