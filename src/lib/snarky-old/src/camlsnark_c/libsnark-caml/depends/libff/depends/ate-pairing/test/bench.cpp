#include "zm.h"
#ifndef XBYAK_NO_OP_NAMES
	#define XBYAK_NO_OP_NAMES
#endif
#include <xbyak/xbyak.h>
#include <xbyak/xbyak_util.h>
#include <stdio.h>
#include <stdlib.h>
#include <memory.h>
#include <iostream>

#define NUM_OF_ARRAY(x) (sizeof(x) / sizeof(*x))

using namespace Xbyak;

const int innerN = 1;

struct Code : CodeGenerator {

	void makeBench(int N, int mode)
	{
#ifdef XBYAK64_WIN
		const Reg64& pz = rcx;
		const Reg64& px = rdx;
		const Reg64& py = r8;
#else
		const Reg64& pz = rdi;
		const Reg64& px = rsi;
		const Reg64& py = rdx;
#endif
		mov(r10, pz);
		mov(r9, px);
		mov(r8, py);
		push(r12);
		push(r13);

		mov(ecx, N);
	L(".lp");
		for (int i = 0; i < innerN; i++) {
			switch (mode) {
			case 0:
				mov(r10, ptr [px]);
				mov(r11, ptr [px + 8]);
				mov(r12, ptr [px + 16]);
				mov(r13, ptr [px + 24]);
				add(r10, r10);
				adc(r8, r11);
				adc(r9, r12);
				adc(py, r13);
				break;
			case 1:
				add(r10, ptr [px]);
				adc(r8, ptr [px + 8]);
				adc(r9, ptr [px + 16]);
				adc(py, ptr [px + 24]);
				break;
			}
		}
		sub(ecx, 1);
		jnz(".lp");
		xor_(eax, eax);
		pop(r13);
		pop(r12);
		ret();
	}
	/*
		[t4:t3:t2:t1:t0] <- py[3:2:1:0] * x
	*/
	void makeMul4x1(const Reg64& t4, const Reg64& t3, const Reg64& t2, const Reg64& t1, const Reg64& t0, const Reg64& py, const Reg64& x)
	{
		const Reg64& a = rax;
		const Reg64& d = rdx;

		mov(a, ptr [py]);
		mul(x);
		mov(t0, a);
		mov(t1, d);
		mov(a, ptr [py + 8]);
		mul(x);
		xor_(t2, t2);
		add(t1, a);
		adc(t2, d);
		mov(a, ptr [py + 16]);
		mul(x);
		xor_(t3, t3);
		add(t2, a);
		adc(t3, d);
		mov(a, ptr [py + 24]);
		mul(x);
		xor_(t4, t4);
		add(t3, a);
		adc(t4, d);
	}
};

mie::Vuint Put(const uint64_t *x, size_t n)
{
	mie::Vuint t;
	t.set(x, n);
	std::cout << t << std::endl;
	return t;
}

void bench(int mode)
{
	const int N = 100000;
	Code code;
	code.makeBench(N, mode);
	int (*p)(uint64_t*, const uint64_t*, const uint64_t*) = code.getCode<int (*)(uint64_t*, const uint64_t*, const uint64_t*)>();

	uint64_t a[4] = { uint64_t(-1), uint64_t(-2), uint64_t(-3), 544443221 };
	uint64_t b[4] = { uint64_t(-123), uint64_t(-3), uint64_t(-4), 222222222 };
	uint64_t c[5] = { 0, 0, 0, 0, 0 };

	const int M = 100;
	Xbyak::util::Clock clk;
	for (int i = 0; i < M; i++) {
		clk.begin();
		p(c, a, b);
		clk.end();
	}
	printf("%.2fclk\n", clk.getClock() / double(M) / double(N) / innerN);
}

struct Call : Xbyak::CodeGenerator {
	Call(const void **p)
	{
		const void *f = (const void *)getCurr();
		sub();
		align(16);
		*p = (const void*)getCurr();
		mov(eax, 3);
		call(f);
		ret();
	}
	void sub()
	{
		add(eax, eax);
		ret();
	}
};

int main(int argc, char *argv[])
{
	argc--, argv++;
	/*
		Core i7
		add :  8.0clk
		mul1: 10.7clk
		mul2: 17.5clk
	*/
	try {
		puts("test0");
		bench(0);
		puts("test1");
		bench(1);
		int (*f)();
		Call call((const void**)&f);
		printf("%d\n", f());
	} catch (std::exception& e) {
		fprintf(stderr, "ExpCode ERR:%s\n", e.what());
	}
}
