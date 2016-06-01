#!/usr/bin/env bash
set -e

cd $(dirname $0)
subjdir=../subjs/
[ ! -d $subjdir ] && mkdir $subjdir

previd=0
prevdate=0
visitno=1
sort -k1,1n -k5,5n txt/sequenceList.txt | awk '(/diff_mddw6/ && $6==203){print}' | 
 while read LunaID BIRCID dbsex dbdob dbvisitdate ndcms protocol dcmvisitdate dcmdob dcmsex path; do
   [ ! -d $path ] && echo "$BIRCID: no path $path !! how does this happend?!" >&2 && continue

   # count visit number -- start over at new lunaids
   # increment at new visitdates
   [ $previd -ne $LunaID ] && visitno=0 
   [ $prevdate -ne $dcmvisitdate ] && let ++visitno

   # update previous 
   previd=$LunaID
   prevdate=$dcmvisitdate

   sdir=$subjdir/${LunaID}_$dcmvisitdate/dti

   # test that we need to link: dont have directory or dont have 203 dicoms
   [ -d $sdir -a $(find $sdir -maxdepth 1 -type l -name '*dcm' |wc -l) -eq 203 ] && continue

   # record visit no and birc id
   echo $visitno > $subjdir/${LunaID}_$dcmvisitdate/visitno.txt
   echo $BIRCID > $subjdir/${LunaID}_$dcmvisitdate/BIRCID.txt

   [ ! -d $sdir ] && mkdir -p $sdir
   ln -s $path/*dcm $sdir/ || echo "$BIRCID: error linking!"
 done
