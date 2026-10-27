CC ?= gcc
CFLAGS ?= -Wall -g

TARGETS ?= blink pwm

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
	for t in $(TARGETS); do \
		install -Dm755 $$t $(DESTDIR)$(out)/bin/$$t; \
	done

clean:
	rm -f blink pwm blink.o pwm.o

.PHONY: all install clean
