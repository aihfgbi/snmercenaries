CC = gcc
CFLAGS = -g -O2 -Wall
SHARED := -fPIC --shared
LUA_CLIB_PATH ?= luaclib
TARGET = lbezier.so

.PHONY : all clean

all : $(TARGET)

$(TARGET) : lbezier.c
	$(CC) $(CFLAGS) $(SHARED) $^ -o $@

clean :
	rm -f $(TARGET)