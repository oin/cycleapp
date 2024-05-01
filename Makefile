INSTALLDIR ?= ~/bin

ifdef RELEASE
MACOS_ARM ?= 1
CCFLAGS := $(CCFLAGS) -O3 -mmacosx-version-min=10.9
else
CCFLAGS := $(CCFLAGS) -g -O0
endif

CCFLAGS := $(CCFLAGS) -fobjc-arc
LDFLAGS := $(LDFLAGS) -framework Cocoa

ifdef MACOS_ARM
CCFLAGS := $(CCFLAGS) -arch x86_64 -arch arm64
endif

.PHONY: clean run install

cycleapp: cycleapp.m
	$(CXX) $^ $(CCFLAGS) $(LDFLAGS) -o $@

install: cycleapp
	cp cycleapp $(INSTALLDIR)

clean:
	rm -f cycleapp
