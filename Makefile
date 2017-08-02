SRC = $(shell find . -name *.chpl)
OUT = bin/main.exe
CHPLFLAGS = --fast --devel
EXTRAFLAGS =

# CHPLFLAGS can be used to add additional compiler flags to Chapel

CollectionAdd-Benchmark:
	chpl testing/Benchmark.chpl collections/DistributedBoundedQueue.chpl \
	testing/collections/AddBenchmark.chpl testing/Plot.chpl collections/SynchronizedList.chpl \
	$(CHPLFLAGS) $(EXTRAFLAGS) --main-module AddBenchmark -o $(OUT)

clean:
	rm $(OUT) $(OUT)_real
