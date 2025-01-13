
# JDK8 := $(shell /usr/libexec/java_home -v 1.8)
ROH=readonlyhash
ROH_FPATH=roh.fpath
ROH_GIT=roh.git

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
	@mkdir -p ~/bin
	@cp -v ./${ROH}.sh ~/bin/${ROH}
	@chmod +x ~/bin/${ROH}
	@cp -v ./${ROH_FPATH}.sh ~/bin/${ROH_FPATH}
	@chmod +x ~/bin/${ROH_FPATH}
	@cp -v ./${ROH_GIT}.sh ~/bin/${ROH_GIT}
	@chmod +x ~/bin/${ROH_GIT}
	@echo "Done."
	@echo

clean:
	rm ~/bin/${ROH}
	rm ~/bin/${ROH_FPATH}
	rm ~/bin/${ROH_GIT}

