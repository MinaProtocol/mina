MODULE_NAME=bn254
JAVA_NAME=BN254
IF_NAME=$(MODULE_NAME)_if
WRAP_CXX=$(IF_NAME)_wrap.cxx
include ../common.mk
LDFLAGS=-lgmp -lgmpxx
ifeq ($(UNAME_S),Darwin)
  JAVA_HOME=$(shell /usr/libexec/java_home)
  JAVA_INC=$(addprefix -I$(JAVA_HOME)/include,/ /darwin)
  LIB_SUF=dylib
else
  JAVA_HOME=$(realpath $(dir $(realpath $(shell which javac)))..)
  JAVA_INC=-I$(JAVA_HOME)/include
  LIB_SUF=so
  CFLAGS+=-z noexecstack
  LIB+=-lrt
endif
CFLAGS+= -shared -fPIC $(JAVA_INC)

PACKAGE_NAME=mcl.$(MODULE_NAME)
PACKAGE_DIR=$(subst .,/,$(PACKAGE_NAME))

TARGET=../bin/lib$(IF_NAME)_wrap.$(LIB_SUF)
JAVA_EXE=cd ../bin && LD_LIBRARY_PATH=./:$(LD_LIBRARY_PATH) java -classpath ../java
all: $(TARGET)

$(IF_NAME)_wrap.cxx: $(IF_NAME).i $(IF_NAME).hpp
	$(MKDIR) $(PACKAGE_DIR)
	swig -java -package $(PACKAGE_NAME) -outdir $(PACKAGE_DIR) -c++ -Wall $<

$(TARGET): $(IF_NAME)_wrap.cxx
	$(MKDIR) ../bin
	$(PRE)$(CXX) $? -o $@ $(CFLAGS) $(LDFLAGS) -I../include ../src/zm2.cpp ../src/zm.cpp -I../../xbyak

%.class: %.java
	javac $<

$(JAVA_NAME)Test.class: $(JAVA_NAME)Test.java $(TARGET)

jar:
	jar cvf $(MODULE_NAME).jar mcl

test: $(JAVA_NAME)Test.class $(TARGET)
	$(JAVA_EXE) $(JAVA_NAME)Test

clean:
	rm -rf *.class $(TARGET) $(PACKAGE_DIR)/*.class $(IF_NAME)_wrap.cxx

