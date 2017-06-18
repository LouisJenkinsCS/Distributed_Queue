CHPL_FILES := $(wildcard */*.chpl)

all:
	echo $(CHPL_FILES);

%.o:%.chpl
	chpl --fast -o $<
