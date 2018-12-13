CC = gcc
CFLAGS = -g -O2 -Wall
SHARED := -fPIC --shared
LUA_CLIB_PATH ?= luaclib
TARGET = lrandom.so

.PHONY : all clean

all : $(TARGET)

$(TARGET) : lrandom.c
	$(CC) $(CFLAGS) $(SHARED) $^ -o $@

clean :
	rm -f $(TARGET)