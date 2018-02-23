# functions to preprocess DTI
SCRIPTDIR=$(cd $(dirname $BASH_SOURCE);pwd)
warn(){ 
 echo $@ >&2
}
err(){
 warn $@
 exit 1
}

GROUPROOTCondor="/Volumes/Zeus/CogDTI/Group_Analysis_Condor/"

SUBJROOT="/Volumes/Zeus/CogDTI/subjs/"
[ ! -d "$SUBJROOT" ] && err "DNE: '$SUBJROOT'"

checkLD(){

  local lunaID=$1
  local scanDate=$2
  [ -z "$scanDate" ] &&  warn "${FUNCNAME[-1]} needs 2 args: luna and date" && return 1

  local ld="${lunaID}_$scanDate"
  local sdir=$SUBJROOT/$ld
  [ ! -d  $sdir ]  && warn "${FUNCNAME[-1]}: DNE: $sdir" && return 1
  echo $sdir
}

# converts dicoms to fsl zipped nifti format and moves image and bval/bvec files to preprocessing folder
dtidcm2nii(){
  origpwd=$(pwd)
  local sdir=$(checkLD $@) || return 1
  cd $sdir
  [ ! -d dti ] && warn "$FUNCNAME cannot run. no raw dir $sdir/dti" && return 1

  local ld=$(basename $sdir)

  # skip if we have everything
  local count=0
  want=(preprocessing/$ld.{bvec,bval,nii.gz})
  for f in ${want[@]}; do [ -r $f ] && let ++count ; done
  [ $count -eq ${#want[@]} ] && echo "$FUNCNAME already complete (have $(pwd)/${want[2]})" && return 0


  echo "CONSTRUCT"
  cd dti
  dcm2nii *.dcm 
  find . -not -iname '*dcm'

  # move results into preprocessing
  [ ! -d ../preprocessing ] && mkdir ../preprocessing
  mv *.nii.gz ../preprocessing/$ld.nii.gz
  mv *.bvec ../preprocessing/$ld.bvec
  mv *.bval ../preprocessing/$ld.bval

  cd $origpwd
}

# returns true if already finished
testDTIfinished() {

  local sdir=$(checkLD $@) || return 1
  local ld=$(basename $sdir)

  # dont rerun if already finished
  [ -r $sdir/analysis/${ld}_RD.nii.gz ] && 
    echo "$FUNCNAME already complete (have $(pwd)/analysis/RD.nii.gz)" && 
    return 0

  return 1
}

processDTI() {
 
  testDTIfinished $@ && return 0

  local sdir=$(checkLD $@) || return 1
  local ld=$(basename $sdir)

  #[ ! -d preprocessing ] && dtidcm2nii $@
  dtidcm2nii $@
  [ ! -r $sdir/preprocessing/${ld}.nii.gz  ] && warn "failed to run dtidcm2nii $@" && return 1


  cd $sdir


  # we need teh analysis directory
  [ ! -d analysis ] && mkdir analysis

  #################
  # PREPROCESSING #
  #################
  cd preprocessing
  echo "PREPROC"

  # skull stripping, also creates a brain mask file
  bet ${ld}.nii.gz ${ld}_brain_mask.nii.gz -f 0.3 -m

  # correct for eddy current distortion and motion
  eddy_correct ${ld}.nii.gz ${ld}_eddy.nii.gz 0

  # should rotate vectors to account for motion correction; however, this is commented out as most people (including susumu mori) say it doesn't matter as long as the rotations aren't huge (and maybe you shouldn't be using your data if they are)
  # rotate_bvecs ${lunaID}_${scanDate}_eddy.ecclog ${lunaID}_${scanDate}.bvec
  # mkdir rotate_bvecs
  # mv *.mat ${lunaID}_${scanDate}.bvec_old rotate_bvecs

  ###################
  # TENSOR ANALYSIS #
  ###################

  echo "ANALYSIS"
  # tensor calculations
  dtifit --data=${ld}_eddy.nii.gz \
         --out=../analysis/${ld} \
         --mask=${ld}_brain_mask.nii.gz \
         --bvecs=${ld}.bvec \
         --bvals=${ld}.bval

  # calculates radial diffusivity, since this is not done by dtifit
  cd ../analysis

  fslmaths ${ld}_L2.nii.gz \
    -add ${ld}_L3.nii.gz \
    -div 2 \
    ${ld}_RD.nii.gz

  #cp *FA.nii.gz /Volumes/TeraByte2/Dani/dti/tbss
}


njobs(){
 jobs -p | wc -l
}
waitForJobs(){
 cfg=$SCRIPTDIR/jobs.cfg
 [ -r $cfg ] && source $cfg
 [ -z $MAXJOBS ] && MAXJOBS=5
 [ -z $SLEEPTIME ] && SLEEPTIME=30
 local cnt=1
 while  [ $(njobs) -ge $MAXJOBS ]; do
   echo "[$(date +%F:%H:%M)] $cnt sleeping for $SLEEPTIME (maxjobs $MAXJOBS)"
   let cnt++
   sleep $SLEEPTIME
 done
}
