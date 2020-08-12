#!/usr/bin/env bash
set -euo pipefail
trap 'e=$?; [ $e -ne 0 ] && echo "$0 exited in error"' EXIT
env|grep -q ^DRYRUN=. && DRYRUN=echo || DRYRUN=

#
#  use mrdb to link in dicoms
#  try to replace 00_mkPtclLst.bash and 01_linkraw.bash
#  20200811WF  init

# lunaid <-> bircid
lncddb "select b.id,l.id from enroll b join enroll l on b.pid=l.pid and b.etype like 'BIRC' and l.etype like 'LunaID'" | mkifdiff txt/id_lookup.txt

# dti sequence
mrdb "select patname, dir from mrinfo where study like 'Cog%' and Name like 'ep2d_diff_mddw6' and ndcm >=203 and ndcm <=204" | while read birc rawdir; do
   dbid=$(echo $birc |sed 's/^0//')
   luna=$(grep $dbid txt/id_lookup.txt|cut -s -f2||echo)
   [ -z "$luna" ] && echo "# $birc missing lunaid!" && continue
   ld8=${luna}_20${birc:0:6}
   sdir=../subjs/$ld8

   [ -d $sdir ] && continue
   echo "* creating $sdir/dti"

   # record visit no and birc id
   $DRYRUN mkdir -p $sdir/dti
   [ -z "$DRYRUN" ] && echo $birc > $sdir/BIRCID.txt
   $DRYRUN ln -s $rawdir/*dcm $sdir/dti || echo "$BIRCID: error linking!"
done
