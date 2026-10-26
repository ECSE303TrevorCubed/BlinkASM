CC ?= gcc
CFLAGS ?= -Wall -g

TARGETS = blink pwm

all: $(TARGETS)

blink: blink.o
	$(CC) -nostdlib -static -o $@ $^

pwm: pwm.o
	$(CC) -o $@ $^ -lwiringPi

blink.o: blink.s
	$(CC) $(CFLAGS) -c -o $@ $<

pwm.o: pwm.s
	$(CC) $(CFLAGS) -c -o $@ $<

install: $(TARGETS)
	install -Dm755 blink $(DESTDIR)$(out)/bin/blink
	install -Dm755 pwm $(DESTDIR)$(out)/bin/pwm

clean:
	rm -f $(TARGETS) blink.o pwm.o

.PHONY: all install clean
