
# JDK8 := $(shell /usr/libexec/java_home -v 1.8)
ROH=readonlyhash
ROH_FPATH=roh.fpath
ROH_GIT=roh.git

# Define the version here or pass it as an environment variable
VERSION := $(shell git describe --tags --long --match v[0-9]*.[0-9]* | sed 's/-g.*$$//')

OUT= build

.PHONY: nothing install obf repo clean

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

install:
	@echo "VERSION: $(VERSION)"
	@mkdir -p ~/bin
	@cp -v ./${ROH}.sh ~/bin/${ROH} # this will get clobbered !
	@echo "#!/bin/bash" > ~/bin/${ROH}
	@echo "" >> ~/bin/${ROH}
	@echo "VERSION=\"$(VERSION)\"" >> ~/bin/${ROH}
	@tail -n +2 ./${ROH}.sh >> ~/bin/${ROH}
	@chmod +x ~/bin/${ROH}
#	
	@cp -v ./${ROH_FPATH}.sh ~/bin/${ROH_FPATH}
	@chmod +x ~/bin/${ROH_FPATH}
	@cp -v ./${ROH_GIT}.sh ~/bin/${ROH_GIT}
	@chmod +x ~/bin/${ROH_GIT}
	@echo "Done."
	@echo

test:
	@./test.sh

clean:
	-rm ~/bin/${ROH}
	-rm ~/bin/${ROH_FPATH}
	-rm ~/bin/${ROH_GIT}
	@echo

