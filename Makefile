
# JDK8 := $(shell /usr/libexec/java_home -v 1.8)
ROH=readonlyhash
ROH_FPATH=roh.fpath
ROH_GIT=roh.git
ROH_COPY=roh.copy

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

gv:
	gv --bash ${ROH}.sh
	gv --bash ${ROH_FPATH}.sh
	gv --bash ${ROH_GIT}.sh
	gv --bash ${ROH_COPY}.sh

install:
	@echo "VERSION: $(VERSION)"
	@mkdir -p ~/bin
#
	@cp -v ./${ROH}.sh ~/bin/${ROH} # this will get clobbered !
	@chmod +x ~/bin/${ROH}
#	
	@cp -v ./${ROH_FPATH}.sh ~/bin/${ROH_FPATH} # this will get clobbered !
	@chmod +x ~/bin/${ROH_FPATH}
#
	@cp -v ./${ROH_GIT}.sh ~/bin/${ROH_GIT} # this will get clobbered !
	@chmod +x ~/bin/${ROH_GIT}
#
	@cp -v ./${ROH_COPY}.sh ~/bin/${ROH_COPY} # this will get clobbered !
	@chmod +x ~/bin/${ROH_COPY}
#
	@echo "Done."
	@echo

test:
	@./test.sh

clean:
	-rm ~/bin/${ROH}
	-rm ~/bin/${ROH_FPATH}
	-rm ~/bin/${ROH_GIT}
	-rm ~/bin/${ROH_COPY}
	@echo

