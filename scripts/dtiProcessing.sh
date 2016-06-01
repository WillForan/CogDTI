#!/bin/bash

set -e #stop if any error occurs
set -x #print out progress on the script

# directory where data is, organized .../luna_id/scan_date/raw, with dicom files in raw directory. within parent, should only be subject folders
#cd /mnt/Schwarzenagger/Governator/DTI_STUDY/ # WILL NEED TO ADD AN EXTRA DIRECTORY FOR SUBJECTS
cd /Volumes/TeraByte2/Dani/dti/script_test
#mkdir /Volumes/TeraByte2/Dani/dti/tbss --> will put FA files in this folder for later TBSS analysis

##################
# SINGLE SUBJECT #
##################

# pulls all subject folders, then loops analysis for each subject
subjects=$( find $PWD -mindepth 1 -maxdepth 1 -type d )
for subject in $subjects
do
    cd $subject
    
    # extracts luna id from data path
    lunaID=$( echo $subject | cut -d "/" -f 7 )

    # finds all scans for subject, then loops analysis for each scan
    scans=$( find $PWD -mindepth 1 -maxdepth 1 -type d )
    for scan in $scans
    do
        cd $scan
        
        # extracts scan date for each scan
        scanDate=$( echo $scan | cut -d "/" -f 8 )
        
        # create preprocessing and analysis directories
        mkdir $scan/preprocessing
        mkdir $scan/analysis
    
        # converts dicoms to fsl zipped nifti format and moves image and bval/bvec files to preprocessing folder
        cd "dti"
        dcm2nii *.dcm
        mv *.nii.gz ../preprocessing/${lunaID}_${scanDate}.nii.gz
        mv *.bvec ../preprocessing/${lunaID}_${scanDate}.bvec
        mv *.bval ../preprocessing/${lunaID}_${scanDate}.bval
        cd ../preprocessing

        #################
        # PREPROCESSING #
        #################

        # skull stripping, also creates a brain mask file
        bet ${lunaID}_${scanDate}.nii.gz ${lunaID}_${scanDate}_brain.nii.gz -f 0.3 -m

        # correct for eddy current distortion and motion
        eddy_correct ${lunaID}_${scanDate}.nii.gz ${lunaID}_${scanDate}_eddy.nii.gz 0

        # should rotate vectors to account for motion correction; however, this is commented out as most people (including susumu mori) say it doesn't matter as long as the rotations aren't huge (and maybe you shouldn't be using your data if they are)
        # rotate_bvecs ${lunaID}_${scanDate}_eddy.ecclog ${lunaID}_${scanDate}.bvec
        # mkdir rotate_bvecs
        # mv *.mat ${lunaID}_${scanDate}.bvec_old rotate_bvecs

        ###################
        # TENSOR ANALYSIS #
        ###################

        # tensor calculations
        dtifit --data=${lunaID}_${scanDate}_eddy.nii.gz --out=../analysis/${lunaID}_${scanDate} --mask=${lunaID}_${scanDate}_brain_mask.nii.gz --bvecs=${lunaID}_${scanDate}.bvec --bvals=${lunaID}_${scanDate}.bval

        # calculates radial diffusivity, since this is not done by dtifit
        cd ../analysis
        fslmaths ${lunaID}_${scanDate}_L2.nii.gz -add ${lunaID}_${scanDate}_L3.nii.gz -div 2 ${lunaID}_${scanDate}_RD.nii.gz

        cp *FA.nii.gz /Volumes/TeraByte2/Dani/dti/tbss

    done

done

#########################
# GROUP ANALYSIS - TBSS #
#########################
