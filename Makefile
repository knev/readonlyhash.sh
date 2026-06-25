
# JDK8 := $(shell /usr/libexec/java_home -v 1.8)
ROH=readonlyhash
ROH_FPATH=roh.fpath
ROH_GIT=roh.git
ROH_COPY=roh.copy

OUT= build

# Resolve the user's real home. Under msys2 `make` (Git Bash) the recipe shell
# resets HOME to the msys home (/home/<user>) -- not on the Git Bash PATH and
# often unwritable -- so invoke Git Bash's `bash` explicitly to get the real
# HOME (/c/Users/<user>). On macOS/Linux this is just $HOME. (Same fix as
# ../gv.git/Makefile.)
TARGET := $(shell bash -c 'echo $$HOME')
UNAME_S := $(shell uname -s)
VERSION := $(shell grep -m1 '^VERSION=' ./$(ROH).sh | cut -d'"' -f2)

.PHONY: nothing install obf repo clean test gv

nothing:
	@echo "usage: make install"

# obf:
# 	@./version.sh --collect --out $(OUT)
# 	@echo "DONE!"

# repo:
# 	#@git add ...
# 	@git status --untracked-files=no
# 	@echo
# 	@./version.sh --print

gv:
	gv --bash ${ROH}.sh
	gv --bash ${ROH_FPATH}.sh
	gv --bash ${ROH_GIT}.sh
	gv --bash ${ROH_COPY}.sh

install:
	@echo "VERSION: $(VERSION)"
	@echo "TARGET:  $(TARGET)/bin"
	@mkdir -p $(TARGET)/bin
#
	@cp -v ./${ROH}.sh $(TARGET)/bin/${ROH} # this will get clobbered !
	@chmod +x $(TARGET)/bin/${ROH}
#	
	@cp -v ./${ROH_FPATH}.sh $(TARGET)/bin/${ROH_FPATH} # this will get clobbered !
	@chmod +x $(TARGET)/bin/${ROH_FPATH}
#
	@cp -v ./${ROH_GIT}.sh $(TARGET)/bin/${ROH_GIT} # this will get clobbered !
	@chmod +x $(TARGET)/bin/${ROH_GIT}
#
	@cp -v ./${ROH_COPY}.sh $(TARGET)/bin/${ROH_COPY} # this will get clobbered !
	@chmod +x $(TARGET)/bin/${ROH_COPY}
#
ifneq (,$(filter MINGW% MSYS% CYGWIN%,$(UNAME_S)))
	@printf '@echo off\r\n"C:\\Program Files\\Git\\bin\\bash.exe" "%%~dp0${ROH}" %%*\r\n' > $(TARGET)/bin/${ROH}.cmd
	@printf '@echo off\r\n"C:\\Program Files\\Git\\bin\\bash.exe" "%%~dp0${ROH_FPATH}" %%*\r\n' > $(TARGET)/bin/${ROH_FPATH}.cmd
	@printf '@echo off\r\n"C:\\Program Files\\Git\\bin\\bash.exe" "%%~dp0${ROH_GIT}" %%*\r\n' > $(TARGET)/bin/${ROH_GIT}.cmd
	@printf '@echo off\r\n"C:\\Program Files\\Git\\bin\\bash.exe" "%%~dp0${ROH_COPY}" %%*\r\n' > $(TARGET)/bin/${ROH_COPY}.cmd
	@echo "created .cmd shims (cmd.exe/PowerShell)"
endif
	@echo "Done."
	@echo

test:
	@./test.sh

clean:
	-rm $(TARGET)/bin/${ROH}
	-rm $(TARGET)/bin/${ROH_FPATH}
	-rm $(TARGET)/bin/${ROH_GIT}
	-rm $(TARGET)/bin/${ROH_COPY}
ifneq (,$(filter MINGW% MSYS% CYGWIN%,$(UNAME_S)))
	-rm $(TARGET)/bin/${ROH}.cmd
	-rm $(TARGET)/bin/${ROH_FPATH}.cmd
	-rm $(TARGET)/bin/${ROH_GIT}.cmd
	-rm $(TARGET)/bin/${ROH_COPY}.cmd
endif
	@echo

