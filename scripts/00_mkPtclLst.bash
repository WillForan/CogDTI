#!/usr/bin/env bash
#WF 20160531

cd $(dirname $0)

[ ! -d txt ] && mkdir txt
log=txt/sequenceList.txt
errlog=txt/sequenceList.err
echo LunaID BIRCID db.sex db.dob db.visitdate ndcms protocol dcm.visitdate dcm.dob dcm.sex path > $log

find /data/Luna1/Raw/{BIRC,NIC}/ -maxdepth 1 -mindepth 1 -type d| while read rawdir; do
  bircid=$(basename $rawdir)
  info=($(mysql -u localadmin -h arnold.wpic.upmc.edu lunadb_nightly -NBe "
    select 
      LunaID,BIRCID, sexID,date_format(DateOfBirth,'%Y%m%d') as dob,
      date_format(VisitDate,'%Y%m%d') as vd
     from tBIRCIDS b
      natural join tsubjectinfo s
      where BIRCID like '$bircid'" ) )
  [ -z "$info" ] && echo "no db entry for $bircid!" >&2 && continue

  [ ${info[2]} == "2" ] && info[2]=F
  [ ${info[2]} == "1" ] && info[2]=M

  for pdir in $rawdir/[0-9]*/;do
     # how many dicoms?
     nd=$(ls $pdir/*dcm|wc -l)
     # scan/subject info
     # dicom info 
     #  0=> protocol 1=>date 2=>dob 3=>sex 
     dinfo=($(dicom_hinfo -tag 0018,1030 -tag 0008,0022 \
                          -tag 0010,0030 -tag 0010,0040 \
                          $(ls $pdir/*dcm|sed 1q) | 
              cut -d' ' -f 2- |
              sed 's/[ 	]+/ /g'))

     # write out all we have on the subject
     echo "${info[@]} $nd ${dinfo[@]} $pdir" 

     # check db against dicom 
     [ "${info[3]}" != "${dinfo[2]}" ] && echo "$birc dob: db ${info[3]} does not match dicom ${dinfo[2]}" >&2
     [ "${info[2]}" != "${dinfo[3]}" ] && echo "$birc sex: db ${info[2]} does not match dicom ${dinfo[3]}" >&2

  done
done 2>$errlog | tee -a $log

exit 0

