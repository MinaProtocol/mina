include ../common.mk

HEADER= ../include/zm.h ../include/bn.h ../include/zm2.h test_point.hpp
TARGET=test_zm bn ../lib/libzm.a

ifeq ($(BIT),-m64)
TARGET += bench_test sample loop_test java_api
endif

all:$(TARGET)

.SUFFIXES: .cpp

test_zm: test_zm.o ../lib/libzm.a
	$(CXX) -o $@ $< $(LDFLAGS) $(BIT)

bn: bn.o ../lib/libzm.a
	$(CXX) -o $@ $< $(LDFLAGS) $(BIT)

sample: sample.o ../lib/libzm.a
	$(CXX) -o $@ $< $(LDFLAGS) $(BIT)

java_api: java_api.o ../lib/libzm.a
	$(CXX) -o $@ $< $(LDFLAGS) $(BIT)

loop_test: loop_test.o ../lib/libzm.a
	$(CXX) -o $@ $< $(LDFLAGS) $(BIT)

bench_test: bench.o ../lib/libzm.a
	$(CXX) -o $@ $< $(LDFLAGS) $(BIT)

../lib/libzm.a: $(HEADER) ../src/zm2.cpp ../src/zm.cpp
	$(MAKE) -C ../src ../lib/libzm.a

clean:
	$(RM) *.o $(TARGET)
	$(MAKE) -C ../src clean

test: $(TARGET)
	./test_zm && ./bn

test_zm.o: test_zm.cpp $(HEADER)
bn.o: bn.cpp $(HEADER)
bench.o: bench.cpp $(HEADER)
sample.o: sample.cpp $(HEADER)
java_api.o: java_api.cpp $(HEADER) ../java/bn254_if.hpp
loop_test.o: loop_test.cpp $(HEADER)
minitest.o: minitest.cpp $(HEADER)

minitest: minitest.o ../lib/libzm.a
	$(CXX) -o $@ $< $(LDFLAGS) $(BIT)

check: minitest
	./minitest
