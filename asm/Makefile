CC ?= gcc
CFLAGS ?= -Wall
LDFLAGS ?= -nostdlib -static

TARGET = blink

all: $(TARGET)

$(TARGET): blink.o
	$(CC) $(LDFLAGS) -o $@ $^

blink.o: blink.s
	$(CC) $(CFLAGS) -c -o $@ $<

install: $(TARGET)
	install -Dm755 $(TARGET) $(DESTDIR)$(out)/bin/$(TARGET)

clean:
	rm -f $(TARGET) blink.o

.PHONY: all install clean
