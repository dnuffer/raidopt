#!/bin/sh
/home/dan/phoronix-test-suite/phoronix-test-suite benchmark ${1:-pts/disk} <<EOS
Y
1
1

n
n
EOS
