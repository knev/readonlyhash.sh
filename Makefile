
# JDK8 := $(shell /usr/libexec/java_home -v 1.8)
ROH=readonlyhash
ROH_FPATH=roh.fpath
ROH_GIT=roh.git
ROH_COPY=roh.copy

OUT= build

UNAME_S := $(shell uname -s)
VERSION := $(shell grep -m1 '^VERSION=' ./$(ROH).sh | cut -d'"' -f2)

# Resolve the install root as a POSIX path. On Windows $HOME differs between Git
# Bash (/c/Users/<user>) and the MSYS2 shell (/home/<user>), so `make install`
# could land in two different places depending on which shell runs make.
# %USERPROFILE% is the same Windows value in both runtimes; cygpath turns it into
# a POSIX path. macOS/Linux: $HOME is already correct. (Same as ../gv.git/Makefile.)
ifneq (,$(filter MINGW% MSYS% CYGWIN%,$(UNAME_S)))
ifeq (,$(USERPROFILE))
$(error %USERPROFILE% is empty -- run native make from Git Bash, or msys64 make from the MSYS2 shell; do NOT run msys64 make from Git Bash (the two msys-2.0.dll runtimes mismarshal the environment))
endif
TARGET := $(shell cygpath -u "$$USERPROFILE")
else
TARGET := $(HOME)
endif

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
	@printf '%s\r\n' '@echo off' '"C:\Program Files\Git\bin\bash.exe" "%~dp0${ROH}" %*' > $(TARGET)/bin/${ROH}.cmd
	@printf '%s\r\n' '@echo off' '"C:\Program Files\Git\bin\bash.exe" "%~dp0${ROH_FPATH}" %*' > $(TARGET)/bin/${ROH_FPATH}.cmd
	@printf '%s\r\n' '@echo off' '"C:\Program Files\Git\bin\bash.exe" "%~dp0${ROH_GIT}" %*' > $(TARGET)/bin/${ROH_GIT}.cmd
	@printf '%s\r\n' '@echo off' '"C:\Program Files\Git\bin\bash.exe" "%~dp0${ROH_COPY}" %*' > $(TARGET)/bin/${ROH_COPY}.cmd
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

