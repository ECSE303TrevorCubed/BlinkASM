CC ?= gcc
CFLAGS ?= -Wall
LDFLAGS ?= -nostdlib -static

TARGETS = blink pwm

all: $(TARGETS)

blink: blink.o
	$(CC) $(LDFLAGS) -o $@ $^

pwm: pwm.o
	$(CC) $(LDFLAGS) -o $@ $^

blink.o: blink.s
	$(CC) $(CFLAGS) -c -o $@ $<

pwm.o: pwm.s
	$(CC) $(CFLAGS) -c -o $@ $<

install: $(TARGETS)
	install -Dm755 blink $(DESTDIR)$(out)/bin/blink
	install -Dm755 pwm $(DESTDIR)$(out)/bin/pwm

clean:
	rm -f $(TARGET) blink.o pwm.o

.PHONY: all install clean
