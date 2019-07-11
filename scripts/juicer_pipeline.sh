#!/bin/bash

## scrspace=/pine/scr/${USER:0:1}/${USER:1:1}/$USER

## FASTQ HANDLING AND JUICER LAUNCHING ##
samplesheet=$1

python /pine/scr/n/e/nekramer/subset_fastqs.py --samplesheet samplesheet
#python /proj/phanstiel_lab/software/launch_pipeline/scripts/subset_fastqs.py --samplesheet samplesheet

## FILE COMPRESSION, RENAMING, MOVING, AND CLEANUP ##

## outputs sample list
samples=($(python /pine/scr/n/e/nekramer/sample_names.py --samplesheet samplesheet | tr -d '[],'))
#samples=($(python /proj/phanstiel_lab/software/launch_pipeline/scripts/sample_names.py --samplesheet samplesheet | tr -d '[],'))

for i in $samples; 
	do eval i=$i;
	## go through each sample's aligned files and gzip everything except inter_30.txt, merged_nodups.txt, and inter_30.hic
	for filename in ./$i/aligned/*;
		do
		if [ $(basename $filename) == "inter_30.txt" ] || [ $(basename $filename) == "merged_nodups.txt" ] || [ $(basename $filename) == "inter_30.hic" ];
 			then continue
 		elif [ -d $(basename $filename) ];
 			then tar czvf $(basename $filename).tar.gz ./$i/aligned/$(basename $filename)

 		else
 	 		gzip $filename
 	fi
 done

 	## go through each sample's debug files and gzip everything	
 	for filename in ./$i/debug/*; do gzip $filename; done

 	## Create sample-specific aligned and debug directories in cluster if they do not exist
	if [ ! -d "/pine/scr/n/e/nekramer/testexport/aligned" ];
		then mkdir --parents "/pine/scr/n/e/nekramer/testexport/aligned"

	fi
	if [ ! -d "/pine/scr/n/e/nekramer/testexport/debug" ];
		then mkdir --parents "/pine/scr/n/e/nekramer/testexport/debug"
	fi

	## Move and rename desired aligned and debug files to cluster with samplename_filename format
	for filename in ./$i/aligned/*; do mv $filename "/pine/scr/n/e/nekramer/testexport/aligned/$i_$filename"; done
	for filename in ./$i/debug/*; do mv $filename "/pine/scr/n/e/nekramer/testexport/debug/$i_$filename"; done

	## CLEANUP FILES ##

	## Unlink all fastq files
	r. ./$i/fastq/*

	## Delete empty fastq directory
	rm -r ./$i/fastq

	## Unlink juicer
	unlink ./$i/juicer

	## Delete empty juicer directory
	rm -r ./$i/juicer

	## Delete everything else
	rm -r ./$i


done






	











