SRC = $(shell find . -name *.chpl)
OBJ = $(SRC:%.chpl=%.o)
BIN = bin/main.exe

all:
	chpl --devel --fast $(SRC) -o $(BIN) --main-module benchmark

NQueens:
	chpl --devel --fast $(SRC) -o $(BIN) --main-module NQueens

clean:
	rm $(BIN) $(BIN)_real
