#!/usr/bin/env bash
cd $(dirname $0)
cnt=1
. funcs_src.bash
ls ../subjs/|xargs -n1 basename | sed 's/_/ /g' | while read luna vdate; do
 echo "==== $luna $vdate ($cnt)"
 let cnt++

 testDTIfinished $luna $vdate && continue 

 ./preproc.bash $luna $vdate &

 waitForJobs
done

