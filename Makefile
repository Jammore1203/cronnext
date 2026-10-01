GNATFLAGS ?= -q -gnat2012 -gnatwa -gnata -O2

.PHONY: all test clean install

all: bin/cronnext

bin/cronnext: src/*.ads src/*.adb
	@mkdir -p bin obj
	gnatmake $(GNATFLAGS) -Isrc -D obj src/cronnext.adb -o $@

bin/test_cron: tests/test_cron.adb src/*.ads src/*.adb
	@mkdir -p bin obj
	gnatmake $(GNATFLAGS) -Isrc -D obj $< -o $@

test: bin/test_cron bin/cronnext
	./bin/test_cron
	./bin/cronnext "*/15 9-17 * * MON-FRI" -n 6 --from "2026-10-02 16:50" > obj/out.txt
	diff -u tests/expected.txt obj/out.txt
	! ./bin/cronnext "61 * * * *" 2>/dev/null
	@echo "CLI tests passed."

install: bin/cronnext
	install -m 755 bin/cronnext $(or $(PREFIX),/usr/local)/bin/cronnext

clean:
	rm -rf bin obj
