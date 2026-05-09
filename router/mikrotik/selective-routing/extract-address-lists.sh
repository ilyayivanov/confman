sed -nE "s/.+list=(\S+).+/\1/p" $1 | uniq
