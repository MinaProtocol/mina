#include <stdio.h>
#include "zm.h"
#include <iostream>
#include <sstream>
#include <cybozu/benchmark.hpp>

using namespace mie;

#define NUM_OF_ARRAY(x) (sizeof(x) / sizeof(*x))

static int s_errNum = 0;
static int s_testNum = 0;

#define TEST_EQUAL(x, y) { s_testNum++; if (x != y) { s_errNum++; printf("%s(%d): err %s != %s\n", __FILE__, __LINE__, #x, #y); std::cout << "lhs=" << (x) << "\nrhs=" << (y) << std::endl; } }
#define TEST_ASSERT(x) { s_testNum++; if (!(x)) { s_errNum++; printf("%s(%d): err assert %s\n", __FILE__, __LINE__, #x); } }

#define FATAL_EXIT(msg) { printf("%s(%d): err %s\n", __FILE__, __LINE__, msg); exit(1); }

struct V {
	int n;
	unsigned int p[16];
};

void testAddSub()
{
	static const struct {
		V a;
		V b;
		V c;
	} tbl[] = {
		{
			{ 1, { 123, } },
			{ 1, { 456, } },
			{ 1, { 579, } },
		},
		{
			{ 1, { 0xffffffff, } },
			{ 1, { 3, } },
			{ 2, { 2, 1 } },
		},
		{
			{ 3, { 0xffffffff, 1,          0xffffffff   } },
			{ 2, { 1,          0xfffffffe,              } },
			{ 4, { 0,          0,          0,         1 } },
		},
		{
			{ 3, { 0xffffffff, 5,          0xffffffff   } },
			{ 2, { 1,          0xfffffffe,              } },
			{ 4, { 0,          4,          0,         1 } },
		},
		{
			{ 3, { 0xffffffff, 5,          0xffffffff } },
			{ 1, { 1, } },
			{ 3, { 0,          6,          0xffffffff } },
		},
		{
			{ 3, { 1,          0xffffffff, 1 } },
			{ 3, { 0xffffffff, 0,          1 } },
			{ 3, { 0,          0,         3 } },
		},
		{
			{ 1, { 1 } },
			{ 3, { 0xffffffff, 0xffffffff, 0xffffffff } },
			{ 4, { 0, 0, 0, 1 } },
		},
		{
			{ 1, { 0xffffffff } },
			{ 1, { 0xffffffff } },
			{ 2, { 0xfffffffe, 1 } },
		},
		{
			{ 2, { 0xffffffff, 0xffffffff } },
			{ 2, { 0xffffffff, 0xffffffff } },
			{ 3, { 0xfffffffe, 0xffffffff, 1 } },
		},
		{
			{ 3, { 0xffffffff, 0xffffffff, 0xffffffff } },
			{ 3, { 0xffffffff, 0xffffffff, 0xffffffff } },
			{ 4, { 0xfffffffe, 0xffffffff, 0xffffffff, 1 } },
		},
		{
			{ 4, { 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff } },
			{ 4, { 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff } },
			{ 5, { 0xfffffffe, 0xffffffff, 0xffffffff, 0xffffffff, 1 } },
		},
		{
			{ 5, { 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff } },
			{ 5, { 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff } },
			{ 6, { 0xfffffffe, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 1 } },
		},
		{
			{ 6, { 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff } },
			{ 6, { 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff } },
			{ 7, { 0xfffffffe, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 1 } },
		},
		{
			{ 7, { 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff } },
			{ 8, { 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff } },
			{ 8, { 0xfffffffe, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 1 } },
		},
		{
			{ 8, { 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff } },
			{ 8, { 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff } },
			{ 9, { 0xfffffffe, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 1 } },
		},
		{
			{ 9, { 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff } },
			{ 9, { 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff } },
			{10, { 0xfffffffe, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 1 } },
		},
		{
			{10, { 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff } },
			{10, { 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff } },
			{11, { 0xfffffffe, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 1 } },
		},
		{
			{11, { 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff } },
			{11, { 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff } },
			{12, { 0xfffffffe, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 1 } },
		},
		{
			{12, { 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff } },
			{12, { 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff } },
			{13, { 0xfffffffe, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 1 } },
		},
		{
			{13, { 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff } },
			{13, { 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff } },
			{14, { 0xfffffffe, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 1 } },
		},
	};
	for (size_t i = 0; i < NUM_OF_ARRAY(tbl); i++) {
		Vuint x, y, z, t;
		x.set(tbl[i].a.p, tbl[i].a.n);
		y.set(tbl[i].b.p, tbl[i].b.n);
		z.set(tbl[i].c.p, tbl[i].c.n);
		Vuint::add(t, x, y);
		TEST_EQUAL(t, z);

		Vuint::add(t, y, x);
		TEST_EQUAL(t, z);

		Vuint::sub(t, z, x);
		TEST_EQUAL(t, y);
	}
	{
		const uint32_t in[] = { 0xffffffff, 0xffffffff };
		const uint32_t out[] = { 0xfffffffe, 0xffffffff, 1 };
		Vuint x, y;
		x.set(in, 2);
		y.set(out, 3);
		Vuint::add(x, x, x);
		TEST_EQUAL(x, y);
		Vuint::sub(x, x, x);
		y.clear();
		TEST_EQUAL(x, y);
	}
	{
		const uint32_t t0[] = {1, 2};
		const uint32_t t1[] = {3, 4, 5};
		const uint32_t t2[] = {4, 6, 5};
		Vuint x, y, z;
		z.set(t2, 3);

		x.set(t0, 2);
		y.set(t1, 3);
		Vuint::add(x, x, y);
		TEST_EQUAL(x, z);

		x.set(t0, 2);
		y.set(t1, 3);
		Vuint::add(x, y, x);
		TEST_EQUAL(x, z);

		x.set(t0, 2);
		y.set(t1, 3);
		Vuint::add(y, x, y);
		TEST_EQUAL(y, z);

		x.set(t0, 2);
		y.set(t1, 3);
		Vuint::add(y, y, x);
		TEST_EQUAL(y, z);
	}
}

void testMul1()
{
	static const struct {
		V a;
		unsigned int b;
		V c;
	} tbl[] = {
		{
			{ 1, { 12, } },
			5,
			{ 1, { 60, } },
		},
		{
			{ 1, { 1234567, } },
			1,
			{ 1, { 1234567, } },
		},
		{
			{ 1, { 1234567, } },
			89012345,
			{ 2, { 0x27F6EDCF, 0x63F2, } },
		},
		{
			{ 3, { 0xffffffff, 0xffffffff, 0xffffffff, } },
			0xffffffff,
			{ 4, { 0x00000001, 0xffffffff, 0xffffffff, 0xfffffffe } },
		},
		{
			{ 3, { 0xffffffff, 0xffffffff, 0xffffffff, } },
			1,
			{ 3, { 0xffffffff, 0xffffffff, 0xffffffff, } },
		},
		{
			{ 2, { 0xffffffff, 1 } },
			0xffffffff,
			{ 3, { 0x00000001, 0xfffffffd, 1 } },
		},
	};
	for (size_t i = 0; i < NUM_OF_ARRAY(tbl); i++) {
		Vuint x, z, t;
		unsigned int y;
		x.set(tbl[i].a.p, tbl[i].a.n);
		y = tbl[i].b;
		z.set(tbl[i].c.p, tbl[i].c.n);
		Vuint::mul(t, x, y);
		TEST_EQUAL(t, z);

		Vuint::mul(x, x, y);
		TEST_EQUAL(x, z);
	}
}

void testMul2()
{
	static const struct {
		V a;
		V b;
		V c;
	} tbl[] = {
		{
			{ 1, { 12, } },
			{ 1, { 5, } },
			{ 1, { 60, } },
		},
		{
			{ 1, { 1234567, } },
			{ 1, { 89012345, } },
			{ 2, { 0x27F6EDCF, 0x63F2, } },
		},
		{
			{ 3, { 0xffffffff, 0xffffffff, 0xffffffff, } },
			{ 1, { 0xffffffff, } },
			{ 4, { 0x00000001, 0xffffffff, 0xffffffff, 0xfffffffe } },
		},
		{
			{ 2, { 0xffffffff, 1 } },
			{ 1, { 0xffffffff, } },
			{ 3, { 0x00000001, 0xfffffffd, 1 } },
		},
		{
			{ 2, { 0xffffffff, 1 } },
			{ 1, { 0xffffffff, } },
			{ 3, { 0x00000001, 0xfffffffd, 1 } },
		},
		{
			{ 2, { 1, 1 } },
			{ 2, { 1, 1 } },
			{ 3, { 1, 2, 1 } },
		},
		{
			{ 3, { 0xffffffff, 0xffffffff, 1 } },
			{ 2, { 0xffffffff, 0xffffffff } },
			{ 5, { 1, 0, 0xfffffffd, 0xffffffff, 1 } },
		},
	};
	for (size_t i = 0; i < NUM_OF_ARRAY(tbl); i++) {
		Vuint x, y, z, t;
		x.set(tbl[i].a.p, tbl[i].a.n);
		y.set(tbl[i].b.p, tbl[i].b.n);
		z.set(tbl[i].c.p, tbl[i].c.n);
		Vuint::mul(t, x, y);
		TEST_EQUAL(t, z);

		Vuint::mul(t, y, x);
		TEST_EQUAL(t, z);
	}
	{
		const uint32_t in[] = { 0xffffffff, 1 };
		const uint32_t out[] = { 1, 0xfffffffc, 3 };
		Vuint x, y, z;
		y.set(out, 3);
		x.set(in, 2);
		z = x;
		Vuint::mul(x, x, x);
		TEST_EQUAL(x, y);

		x.set(in, 2);
		Vuint::mul(x, x, z);
		TEST_EQUAL(x, y);

		x.set(in, 2);
		Vuint::mul(x, z, x);
		TEST_EQUAL(x, y);

		x.set(in, 2);
		Vuint::mul(x, z, z);
		TEST_EQUAL(x, y);
	}
	{
		Vuint a("285434247217355341057");
		a *= a;
		TEST_EQUAL(a, Vuint("81472709484538325259309302444004789877249"));
	}
}

void testDiv1()
{
	static const struct {
		V a;
		unsigned int b;
		unsigned int r;
		V c;
	} tbl[] = {
		{
			{ 1, { 100, } },
			1, 0,
			{ 1, { 100, } },
		},
		{
			{ 1, { 100, } },
			100, 0,
			{ 1, { 1, } },
		},
		{
			{ 1, { 100, } },
			101, 100,
			{ 1, { 0, } },
		},
		{
			{ 1, { 100, } },
			2, 0,
			{ 1, { 50, } },
		},
		{
			{ 1, { 100, } },
			3, 1,
			{ 1, { 33, } },
		},
		{
			{ 2, { 0xffffffff, 0xffffffff } },
			1, 0,
			{ 2, { 0xffffffff, 0xffffffff, } },
		},
		{
			{ 2, { 0xffffffff, 0xffffffff } },
			123, 15,
			{ 2, { 0x4d0214d0, 0x214d021 } },
		},
	};
	for (size_t i = 0; i < NUM_OF_ARRAY(tbl); i++) {
		Vuint x, z, t;
		unsigned int b, r, u;
		x.set(tbl[i].a.p, tbl[i].a.n);
		b = tbl[i].b;
		r = tbl[i].r;
		z.set(tbl[i].c.p, tbl[i].c.n);

		u = (unsigned int)Vuint::div1(&t, x, b);
		TEST_EQUAL(t, z);
		TEST_EQUAL(u, r);

		u = (unsigned int)Vuint::div1(&x, x, b);
		TEST_EQUAL(x, z);
		TEST_EQUAL(u, r);
	}
}



void testDiv2()
{
	static const struct {
		V x;
		V y;
		V q;
		V r;
	} tbl[] = {
		{
			{ 1, { 100 } },
			{ 1, { 3 } },
			{ 1, { 33 } },
			{ 1, { 1 } },
		},
		{
			{ 2, { 1, 1 } },
			{ 2, { 0, 1 } },
			{ 1, { 1 } },
			{ 1, { 1 } },
		},
		{
			{ 2, { 0xffffffff, 0xffffffff } },
			{ 2, { 0, 1 } },
			{ 1, { 0xffffffff } },
			{ 1, { 0xffffffff } },
		},
		{
			{ 2, { 0xffffffff, 0xffffffff } },
			{ 2, { 0xffffffff, 1 } },
			{ 1, { 0x80000000 } },
			{ 1, { 0x7fffffff } },
		},
		{
			{ 3, { 0xffffffff, 0xffffffff, 0xffffffff } },
			{ 2, { 0xffffffff, 1 } },
			{ 2, { 0x40000000, 0x80000000 } },
			{ 1, { 0x3fffffff } },
		},
		{
			{ 4, { 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff } },
			{ 3, { 1, 0, 1 } },
			{ 2, { 0xffffffff, 0xffffffff } },
			{ 1, { 0 } },
		},
		{
			{ 4, { 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff } },
			{ 3, { 1, 0xffffffff, 0xffffffff } },
			{ 2, { 0, 1 } },
			{ 2, { 0xffffffff, 0xfffffffe } },
		},
		{
			{ 4, { 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff } },
			{ 3, { 1, 0, 0xffffffff } },
			{ 2, { 1, 1 } },
			{ 2, { 0xfffffffe, 0xfffffffe } },
		},
		{
			{ 4, { 0xffffffff, 0xffffffff, 0xffffffff, 1 } },
			{ 3, { 1, 0, 0xffffffff } },
			{ 1, { 2 } },
			{ 3, { 0xfffffffd, 0xffffffff, 1 } },
		},
		{
			{ 4, { 0, 0, 1, 1 } },
			{ 2, { 1, 1 } },
			{ 3, { 0, 0, 1 } },
			{ 1, { 0 } },
		},
		{
			{ 3, { 5, 5, 1} },
			{ 2, { 1, 2 } },
			{ 1, { 0x80000002 } },
			{ 1, { 0x80000003, } },
		},
		{
			{ 2, { 5, 5} },
			{ 2, { 1, 1 } },
			{ 1, { 5 } },
			{ 1, { 0, } },
		},
		{
			{ 2, { 5, 5} },
			{ 2, { 2, 1 } },
			{ 1, { 4 } },
			{ 1, { 0xfffffffd, } },
		},
		{
			{ 3, { 5, 0, 5} },
			{ 3, { 2, 0, 1 } },
			{ 1, { 4 } },
			{ 2, { 0xfffffffd, 0xffffffff } },
		},
		{
			{ 2, { 4, 5 } },
			{ 2, { 5, 5 } },
			{ 1, { 0 } },
			{ 2, { 4, 5 } },
		},
	};
	for (size_t i = 0; i < NUM_OF_ARRAY(tbl); i++) {
		Vuint x, y, q, r;
		x.set(tbl[i].x.p, tbl[i].x.n);
		y.set(tbl[i].y.p, tbl[i].y.n);
		q.set(tbl[i].q.p, tbl[i].q.n);
		r.set(tbl[i].r.p, tbl[i].r.n);

		Vuint qt, rt;
		Vuint::div(&qt, rt, x, y);
		TEST_EQUAL(qt, q);
		TEST_EQUAL(rt, r);

		Vuint::mul(y, y, qt);
		Vuint::add(y, y, rt);
		TEST_EQUAL(x, y);

		x.set(tbl[i].x.p, tbl[i].x.n);
		y.set(tbl[i].y.p, tbl[i].y.n);
		Vuint::div(&x, rt, x, y);
		TEST_EQUAL(x, q);
		TEST_EQUAL(rt, r);

		x.set(tbl[i].x.p, tbl[i].x.n);
		y.set(tbl[i].y.p, tbl[i].y.n);
		Vuint::div(&y, rt, x, y);
		TEST_EQUAL(y, q);
		TEST_EQUAL(rt, r);

		x.set(tbl[i].x.p, tbl[i].x.n);
		y.set(tbl[i].y.p, tbl[i].y.n);
		Vuint::div(&x, y, x, y);
		TEST_EQUAL(x, q);
		TEST_EQUAL(y, r);

		x.set(tbl[i].x.p, tbl[i].x.n);
		y.set(tbl[i].y.p, tbl[i].y.n);
		Vuint::div(&y, x, x, y);
		TEST_EQUAL(y, q);
		TEST_EQUAL(x, r);
	}
	{
		const uint32_t in[] = { 1, 1 };
		Vuint x, y, z;
		x.set(in, 2);
		Vuint::div(&x, y, x, x);
		z.set(1);
		TEST_EQUAL(x, z);
		z.clear();
		TEST_EQUAL(y, z);

		Vuint::div(&y, x, x, x);
		z.set(1);
		TEST_EQUAL(y, z);
		z.clear();
		TEST_EQUAL(x, z);
	}
}

void testDiv3()
{
	const struct {
		const char *x;
		const char *y;
		const char *r;
	} tbl[] = {
		{
			"1448106640508192452750709206294683535529268965445799785581837640324321797831381715960812126274894517677713278300997728292641936248881345120394299128611830",
			"82434016654300679721217353503190038836571781811386228921167322412819029493183",
			"72416512377294697540770834088766459385112079195086911762075702918882982361282"
		},
		{
			"97086308670107713719105336221824613370040805954034005192338040686500414395543303807941158656814978071549225072789349941064484974666540443679601226744652",
			"82434016654300679721217353503190038836571781811386228921167322412819029493183",
			"41854959563040430269871677548536437787164514279279911478858426970427834388586",
		},
		{
			"726838724295606887174238120788791626017347752989142414466410919788841485181240131619880050064495352797213258935807786970844241989010252",
			"82434016654300679721217353503190038836571781811386228921167322412819029493183",
			"81378967132566843036693176764684783485107373533583677681931133755003929106966",
		},
		{
			"85319207237201203511459960875801690195851794174784746933408178697267695525099750",
			"82434016654300679721217353503190038836571781811386228921167322412819029493183",
			"82434016654300679721217353503190038836571781811386228921167322412819029148528",
		},
		{
			"0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffff",
			"0x100000000000000000000000000000000000000000000000001",
			"1606938044258990275541962092341162602522202993782724115824640",
		},
		{
			"0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff",
			"0x1000000000000000000000000000000000000000000000000000000000000000000000000000000001",
			"34175792574734561318320347298712833833643272357332299899995954578095372295314880347335474659983360",
		},
		{
			"0xfffffffffffff000000000000000000000000000000000000000000000000000000000000000000",
			"0x100000000000000000000000000000000000000000000000000000000000000000001",
			"7558907585412001237250713901367146624661464598973016020495791084036551510708977665",
		},
		{
			"0xfffffffffffff000000000000000000000000000000000000000000000000000000000000000000",
			"0xfffffffffffff0000000000000000000000000000000000000000000000000000000000000001",
			"521481209941628322292632858916605385658190900090571826892867289394157573281830188869820088065",
		},
	};
	mie::Vuint x, y, r;
	for (size_t i = 0; i < NUM_OF_ARRAY(tbl); i++) {
		x.set(tbl[i].x);
		y.set(tbl[i].y);
		r.set(tbl[i].r);
		x %= y;
		TEST_EQUAL(x, r);
	}
}

void testString()
{
	const struct {
		uint32_t v[5];
		size_t vn;
		const char *str;
		const char *hex;
	} tbl[] = {
		{ { 0 }, 0, "0", "0x0" },
		{ { 12345 }, 1, "12345", "0x3039" },
		{ { 0xffffffff }, 1, "4294967295", "0xffffffff" },
		{ { 0, 1 }, 2, "4294967296", "0x100000000" },
		{ { 0, 0, 0, 0, 1 }, 5, "340282366920938463463374607431768211456", "0x100000000000000000000000000000000" },
	};
	for (size_t i = 0; i < NUM_OF_ARRAY(tbl); i++) {
		Vuint x, y;
		x.set(tbl[i].v,tbl[i].vn);
		TEST_EQUAL(x.toString(10), tbl[i].str);
		y.set(tbl[i].str);
		TEST_EQUAL(x, y);
		x = 1;
		x.set(tbl[i].hex);
		TEST_EQUAL(x, y);
	}
}

void testZmZ()
{
	const Vuint m = 13;
	ZmZ<>::setModulo(m);
	TEST_EQUAL(ZmZ<>::getModulo(), m);
	ZmZ<> x(2);
	x *= 10;
	TEST_EQUAL(x, 7);
	x -= 10;
	TEST_EQUAL(x, 10);
	x = -1;
	TEST_EQUAL(x, 12);
	x = 4;
	x.inverse();
	TEST_EQUAL(x, 10);
}

void testZmZsub()
{
	const uint32_t tbl1[] = { 0, 0, 1 };
	const uint32_t tbl2[] = { 0, 1 };
	const uint32_t tbl3[] = { 1, 0xffffffff };
	Vuint m;
	m.set(tbl1, 3);
	ZmZ<>::setModulo(m);
	ZmZ<> x, y, z;
	x = 1;
	y.set(tbl2, 2);
	x = x - y;
	z.set(tbl3, 2);
	TEST_EQUAL(x, z);
	x = 0;
	y = 4;
	ZmZ<>::sub(y, x, y);
	TEST_EQUAL(y, ZmZ<>("0xfffffffffffffffc"));
}

void testInverse()
{
	const Vuint m("1461501637330902918203684832716283019655932542983");
	ZmZ<>::setModulo(m);
	ZmZ<> x, y, z;
	x = 1;
	y.set("1461501637330902918203684832716283019655932542927");
	y = x - y;
	TEST_EQUAL(y, 57);
	x.set("51309926569953339959415154564163853983901484416");
	y = x;
	y.inverse();
	z.set("123456789");
	TEST_EQUAL(y, z);
	z = 1 / z;
	TEST_EQUAL(z, x);
	y = 3;
	y /= x;
	z.set("370370367");
	TEST_EQUAL(y, z);
}

void testPow()
{
	Vuint m = 2, d = 2;
	for (size_t i = 0; i < 160 - 1; i++) {
		m *= d;
	}
	m += 7;
	ZmZ<>::setModulo(m);
	TEST_EQUAL(m, Vuint("1461501637330902918203684832716283019655932542983"));

	ZmZ<> x, y = ZmZ<>(m) - 1;
	x = 3;
	x = mie::power(x, y);
	TEST_EQUAL(x, 1);
	CYBOZU_BENCH("power", x = mie::power, x, y);
}

void testShift()
{
	Vuint x("123423424918471928374192874198274981274918274918274918243");
	Vuint y, z;

	// shl
	for (size_t i = 1; i < sizeof(mie::Unit) * 8; i++) {
		Vuint::shlBit(y, x, i);
		z = x * (mie::Unit(1) << i);
		TEST_EQUAL(y, z);
		y = x << i;
		TEST_EQUAL(y, z);
		y = x;
		y <<= i;
		TEST_EQUAL(y, z);
	}
	for (size_t i = 0; i < 4; i++) {
		Vuint::shlUnit(y, x, i);
		Vuint s = power(Vuint(2), Vuint(i * sizeof(mie::Unit) * 8));
		z = x * s;
		TEST_EQUAL(y, z);
		y = x << (i * sizeof(mie::Unit) * 8);
		TEST_EQUAL(y, z);
		y = x;
		y <<= (i * sizeof(mie::Unit) * 8);
		TEST_EQUAL(y, z);
	}
	for (size_t i = 0; i < 100; i++) {
		y = x << i;
		Vuint s = power(Vuint(2), Vuint(i));
		z = x * s;
		TEST_EQUAL(y, z);
		y = x;
		y <<= i;
		TEST_EQUAL(y, z);
	}

	// shr
	for (size_t i = 1; i < sizeof(mie::Unit) * 8; i++) {
		Vuint::shrBit(y, x, i);
		z = x / (mie::Unit(1) << i);
		TEST_EQUAL(y, z);
		y = x >> i;
		TEST_EQUAL(y, z);
		y = x;
		y >>= i;
		TEST_EQUAL(y, z);
	}
	for (size_t i = 0; i < 3; i++) {
		Vuint::shrUnit(y, x, i);
		Vuint s = power(Vuint(2), Vuint(i * sizeof(mie::Unit) * 8));
		z = x / s;
		TEST_EQUAL(y, z);
		y = x >> (i * sizeof(mie::Unit) * 8);
		TEST_EQUAL(y, z);
		y = x;
		y >>= (i * sizeof(mie::Unit) * 8);
		TEST_EQUAL(y, z);
	}
	for (size_t i = 0; i < 100; i++) {
		y = x >> i;
		Vuint s = power(Vuint(2), Vuint(i));
		z = x / s;
		TEST_EQUAL(y, z);
		y = x;
		y >>= i;
		TEST_EQUAL(y, z);
	}
	{
		Vuint a = 0, zero = 0;
		a <<= sizeof(Vuint::T) * 8;
		TEST_EQUAL(a, zero);
	}
}

void testBitLen()
{
  {
    Vuint zero = 0;
    TEST_EQUAL(zero.bitLen(), 0);
    zero <<= (sizeof(Vuint::T)*8 - 1);
    TEST_EQUAL(zero.bitLen(), 0);
    zero <<= (sizeof(Vuint::T)*8);
    TEST_EQUAL(zero.bitLen(), 0);
  }

  {
    Vuint a = 1;
    TEST_EQUAL(a.bitLen(), 1);
    a = 2;
    TEST_EQUAL(a.bitLen(), 2);
    a = 3;
    TEST_EQUAL(a.bitLen(), 2);
    a = 4;
    TEST_EQUAL(a.bitLen(), 3);
  }

  {
    Vuint a = 5;
    const size_t msbindex = a.bitLen();
    const size_t width = 100;
    const size_t time = 3;
    for (size_t i = 0; i < time; ++i) {
      a <<= width;
      TEST_EQUAL(a.bitLen(), msbindex + width*(i + 1));
    }

    for (size_t i = 0; i < time*2; ++i) {
      a >>= width/2;
      TEST_EQUAL(a.bitLen(), msbindex + width*time - (width/2)*(i + 1));
    }
    a >>= width;
    TEST_EQUAL(a.bitLen(), 0);
  }

  {
    Vuint b("12"), c("345"), d("67890");
    size_t bl = b.bitLen(), cl = c.bitLen(), dl = d.bitLen();
    TEST_ASSERT((b*c).bitLen()   <= bl + cl);
    TEST_ASSERT((c*d).bitLen()   <= cl + dl);
    TEST_ASSERT((b*c*d).bitLen() <= bl + cl + dl);
  }
}

void testTestBit()
{
  {
    Vuint a;
    a.set("0x1234567890abcdef");
    bool tvec[] = {
      1,1,1,1,0  ,1,1,1,1,0
      ,1,1,0,0,1 ,1,1,1,0,1
      ,0,1,0,1,0 ,0,0,0,1,0
      ,0,1,0,0,0 ,1,1,1,1,0
      ,0,1,1,0,1 ,0,1,0,0,0
      ,1,0,1,1,0 ,0,0,1,0,0
      ,1
    };
    TEST_EQUAL(a.bitLen(), sizeof(tvec)/sizeof(*tvec));
    for (int i = (int)a.bitLen() - 1; i >= 0; --i) {
      TEST_EQUAL(a.testBit(i), tvec[i]);
    }
  }
}

void bench()
{
	Vuint m("16798108731015832284940804142231733909759579603404752749028378864165570215949");
	ZmZ<>::setModulo(m);
	const char *str = "82434016654300679721217353503190038836571781811386228921167322412819029493182";
	Vuint a(str), b(a);
	CYBOZU_BENCH("Vuint:mul", Vuint::mul, b, a, a);
}

void sample()
{
	using namespace mie;
	Vuint x(1);
	Vuint y("123456789");
	Vuint z;

	x = 1;	// set by int
	y.set("123456789"); // set by decimal
	z.set("0xffffffff"); // set by hex
	x += z;

	x = 2;
	y = 250;
	x = power(x, y);
	Vuint r, q;
	r = x % y;
	q = x / y;
	TEST_EQUAL(q * y + r, x);

	Vuint::div(&q, r, x, y); // get both r and q
	TEST_EQUAL(q * y + r, x);

	Vuint m;
	m = power(Vuint(2), Vuint(160)) + Vuint(7);
	ZmZ<>::setModulo(m);
	ZmZ<> a, b(m - 1);
	a = 3;
	a = power(a, b);
	TEST_EQUAL(a, 1);
}

void testVsint()
{
	const struct {
		int a;
		int b;
		int add, sub, mul, q, r;
	} tbl[] = {
#if 1 // like Python
		{  13,  5,  18,   8,  65,  2,  3 },
		{  13, -5,   8,  18, -65, -3, -2 },
		{ -13,  5,  -8, -18, -65, -3,  2 },
		{ -13, -5, -18,  -8,  65,  2, -3 },

		{  5,  13,  18,  -8,  65,  0,  5 },
		{  5, -13,  -8,  18, -65, -1, -8 },
		{ -5,  13,   8, -18, -65, -1,  8 },
		{ -5, -13, -18,   8,  65,  0, -5 },
#else // like C
		{  13,  5,  18,   8,  65,  2,  3 },
		{  13, -5,   8,  18, -65, -2,  3 },
		{ -13,  5,  -8, -18, -65, -2, -3 },
		{ -13, -5, -18,  -8,  65,  2, -3 },

		{  5,  13,  18,  -8,  65, 0,  5 },
		{  5, -13,  -8,  18, -65, 0,  5 },
		{ -5,  13,   8, -18, -65, 0, -5 },
		{ -5, -13, -18,   8,  65, 0, -5 },
#endif
	};
	for (size_t i = 0; i < NUM_OF_ARRAY(tbl); i++) {
		Vsint a = tbl[i].a;
		Vsint b = tbl[i].b;
		Vsint add = a + b;
		Vsint sub = a - b;
		Vsint mul = a * b;
		Vsint q = a / b;
		Vsint r = a % b;
		TEST_EQUAL(add, tbl[i].add);
		TEST_EQUAL(sub, tbl[i].sub);
		TEST_EQUAL(mul, tbl[i].mul);
		TEST_EQUAL(q, tbl[i].q);
		TEST_EQUAL(r, tbl[i].r);
		TEST_EQUAL(q * b + r, a);
	}
	TEST_EQUAL(Vsint("15") / Vsint("3"), Vsint("5"));
	TEST_EQUAL(Vsint("15") / Vsint("-3"), Vsint("-5"));
	TEST_EQUAL(Vsint("-15") / Vsint("3"), Vsint("-5"));
	TEST_EQUAL(Vsint("-15") / Vsint("-3"), Vsint("5"));

	TEST_EQUAL(Vsint("15") % Vsint("3"), Vsint("0"));
	TEST_EQUAL(Vsint("15") % Vsint("-3"), Vsint("0"));
	TEST_EQUAL(Vsint("-15") % Vsint("3"), Vsint("0"));
	TEST_EQUAL(Vsint("-15") % Vsint("-3"), Vsint("0"));

	TEST_EQUAL(Vsint("-0") + Vsint("-3"), Vsint("-3"));
	TEST_EQUAL(Vsint("-0") - Vsint("-3"), Vsint("3"));
	TEST_EQUAL(Vsint("-3") + Vsint("-0"), Vsint("-3"));
	TEST_EQUAL(Vsint("-3") - Vsint("-0"), Vsint("-3"));

	TEST_EQUAL(Vsint("-0") + Vsint("3"), Vsint("3"));
	TEST_EQUAL(Vsint("-0") - Vsint("3"), Vsint("-3"));
	TEST_EQUAL(Vsint("3") + Vsint("-0"), Vsint("3"));
	TEST_EQUAL(Vsint("3") - Vsint("-0"), Vsint("3"));

	TEST_EQUAL(Vsint("0"), Vsint("0"));
	TEST_EQUAL(Vsint("0"), Vsint("-0"));
	TEST_EQUAL(Vsint("-0"), Vsint("0"));
	TEST_EQUAL(Vsint("-0"), Vsint("-0"));

	TEST_ASSERT(Vsint("2") < Vsint("3"));
	TEST_ASSERT(Vsint("-2") < Vsint("3"));
	TEST_ASSERT(Vsint("-5") < Vsint("-3"));
	TEST_ASSERT(Vsint("-0") < Vsint("1"));
	TEST_ASSERT(Vsint("-1") < Vsint("-0"));

	TEST_ASSERT(Vsint("5") > Vsint("3"));
	TEST_ASSERT(Vsint("5") > Vsint("-3"));
	TEST_ASSERT(Vsint("-2") > Vsint("-3"));
	TEST_ASSERT(Vsint("3") > Vsint("-0"));
	TEST_ASSERT(Vsint("-0") > Vsint("-1"));

	{
		const struct {
			const char *str;
			int s;
			int shl;
			int shr;
		} tbl[] = {
			{ "0", 1, 0, 0 },
			{ "-0", 1, 0, 0 },
			{ "1", 1, 2, 0 },
			{ "-1", 1, -2, 0 },
			{ "12345", 3, 98760, 1543 },
			{ "-12345", 3, -98760, 0 },
		};
		for (size_t i = 0; i < NUM_OF_ARRAY(tbl); i++) {
			Vsint a = Vsint(tbl[i].str);
			Vsint shl = a << tbl[i].s;
			TEST_EQUAL(shl, tbl[i].shl);
			if (!a.isNegative()) {
				Vsint shr = a >> tbl[i].s;
				TEST_EQUAL(shr, tbl[i].shr);
			}
		}
	}
}

void testAdd2()
{
	Vuint x, y, z, w;
	x.set("2416089439321382744001761632872637936198961520379024187947524965775137204955564426500438089001375107581766516460437532995850581062940399321788596606850");
	y.set("2416089439321382743300544243711595219403446085161565705825288050160594425031420687263897209379984490503106207071010949258995096347962762372787916800000");
	z.set("701217389161042716795515435217458482122236915614542779924143739236540879621390617078660309389426583736855484714977636949000679806850");
	Vuint::sub(w, x, y);
	TEST_EQUAL(w, z);

	Vsint a, c, d;

	a.set("-2416089439321382744001761632872637936198961520379024187947524965775137204955564426500438089001375107581766516460437532995850581062940399321788596606850");
	c.set("2416089439321382743300544243711595219403446085161565705825288050160594425031420687263897209379984490503106207071010949258995096347962762372787916800000");
	a = a + c;

	d.set("-701217389161042716795515435217458482122236915614542779924143739236540879621390617078660309389426583736855484714977636949000679806850");
	TEST_EQUAL(a, d);
}

void testStream()
{
	{
		Vuint x, y, z, w;
		x.set("12345678901232342424242423423429922");
		y.set("23423423452424242343");
		std::ostringstream oss;
		oss << x << ' ' << y;
		std::istringstream iss(oss.str());
		iss >> z >> w;
		TEST_EQUAL(x, z);
		TEST_EQUAL(y, w);
	}
	{
		Vuint x, y, z, w;
		x.set("0x100");
		y.set("123");
		std::ostringstream oss;
		oss << x << ' ' << y;
		std::istringstream iss(oss.str());
		iss >> z >> w;
		TEST_EQUAL(x, z);
		TEST_EQUAL(y, w);
	}
	{
		Vsint x, y, z, w;
		x.set("12345678901232342424242423423429922");
		y.set("-23423423452424242343");
		std::ostringstream oss;
		oss << x << ' ' << y;
		std::istringstream iss(oss.str());
		iss >> z >> w;
		TEST_EQUAL(x, z);
		TEST_EQUAL(y, w);
	}
}

int main()
{
	mie::zmInit();
	testAdd2();
	testAddSub();
	testMul1();
	testMul2();
	testDiv1();
	testDiv2();
	testDiv3();
	testString();
	testZmZ();
	testZmZsub();
	testInverse();
	testPow();
	testShift();
	testBitLen();
	testTestBit();
	testVsint();
	testStream();
	sample();
#ifdef NDEBUG
	bench();
#endif
	printf("err=%d(test=%d)\n", s_errNum, s_testNum);
}
