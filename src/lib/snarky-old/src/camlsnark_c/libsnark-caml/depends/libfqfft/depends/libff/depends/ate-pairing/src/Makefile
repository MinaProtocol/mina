include ../common.mk

ifeq ($(UNAME_S),Darwin)
  LIB_SUF=dylib
else
  LIB_SUF=so
endif

TARGET=../lib/libzm.a
all:$(TARGET)

OBJ=zm2.o zm.o
clean:
	$(RM) *.o $(TARGET)

../lib/libzm.a: $(OBJ)
	$(MKDIR) ../lib
	-$(RM) $@
	$(AR) $@ $(OBJ)
	$(CXX) -fPIC -shared -o ../lib/zm.$(LIB_SUF) $(OBJ)

zm.o: zm.cpp ../include/zm.h
zm2.o: zm2.cpp ../include/zm2.h ../include/bn.h

