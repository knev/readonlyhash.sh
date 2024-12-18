
# JDK8 := $(shell /usr/libexec/java_home -v 1.8)
ROH=readonlyhash.sh
ROH_BIN=readonlyhash
ROH_GIT=roh_git.sh
ROH_GIT_BIN=roh_git

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
	@cp -v ./${ROH} ~/bin/${ROH_BIN}
	chmod +x ~/bin/${ROH_BIN}
	@cp -v ./${ROH_GIT} ~/bin/${ROH_GIT_BIN}
	chmod +x ~/bin/${ROH_GIT_BIN}

# clean:
# 	rm -rf $(OUT) src/se/mitm/version 

