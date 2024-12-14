
# JDK8 := $(shell /usr/libexec/java_home -v 1.8)
ROH=readonlyhash.sh
BIN=readonlyhash
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
	@cp -v ./${ROH} ~/bin/${BIN}
	chmod +x ~/bin/${BIN}

# clean:
# 	rm -rf $(OUT) src/se/mitm/version 

