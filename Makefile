
# ability to change the bash binary used.
SHELL = bash
SHELLCHECK = bin/shellcheck
SHUNIT = bin/shunit2.sh

TEST_FILES = tests/verbosity
# bash files to be checked by shellcheck
CHECK_FILES = verbosity.sh tests/verbosity tests/demo

TEST_TARGET_PREFIX = "TEST-TARGET-"

# append prefix to not match existing directory/file
TEST_FILES_RUN_TARGET = $(patsubst %,$(TEST_TARGET_PREFIX)%,$(TEST_FILES))

.DEFAULT_GOAL := ci

.PHONY: ci-watch
ci-watch:
	while : ;\
	do \
    	$(MAKE) ci; \
    	inotifywait -e close_write -r .; \
	done

.PHONY: ci
ci:: check tests demo

.PHONY: check
check:: | $(SHELLCHECK) $(SHUNIT)
	$(SHELLCHECK) --enable=all --external-sources -s bash -S style -P SCRIPTDIR $(CHECK_FILES)

.PHONY: tests
tests:: unit-tests

.PHONY: unit-tests
unit-tests:: $(TEST_FILES_RUN_TARGET)

.PHONY: demo
demo::
	$(SHELL) tests/demo

.PHONY: clean
clean::
	# use interactive because user might have put a non generated file
	! test -d bin || rm -r --interactive=once bin

$(SHELLCHECK):
	mkdir -p $$(dirname $(SHELLCHECK))
	wget -q -O shellcheck.tar.xz https://storage.googleapis.com/shellcheck/shellcheck-stable.linux.x86_64.tar.xz
	tar -x -O -f shellcheck.tar.xz shellcheck-stable/shellcheck > $(SHELLCHECK)
	rm shellcheck.tar.xz
	chmod u+x $(SHELLCHECK)

$(SHUNIT):
	mkdir -p $$(dirname $(SHUNIT))
	wget -q -O $(SHUNIT) https://raw.githubusercontent.com/kward/shunit2/master/shunit2
	chmod u+x $(SHUNIT)

.PHONY: $(TEST_FILES_RUN_TARGET)
$(TEST_FILES_RUN_TARGET): | $(SHUNIT)
	$(SHELL) ${SHUNIT} $(patsubst $(TEST_TARGET_PREFIX)%,%,$@)
