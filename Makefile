SRC = $(shell find . -name *.chpl)
OBJ = $(SRC:%.chpl=%.o)
BIN = bin/main.exe

all:
	chpl --devel --fast $(SRC) -o $(BIN) --main-module benchmark

NQueens:
	chpl --devel --fast queues/distributed/DistributedFIFOQueue.chpl \
	benchmark/NQueens.chpl queues/Queue.chpl queues/local/SyncQueue.chpl \
	-o $(BIN) --main-module NQueens

clean:
	rm $(BIN) $(BIN)_real
