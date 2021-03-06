#!/bin/bash

## FILE COMPRESSION, RENAMING, MOVING, AND CLEANUP ##



samplesheet=$1
## outputs sample list
<<<<<<< HEAD
samples=($(python /proj/phanstiel_lab/software/launch_pipeline/scripts/sample_names.py --samplesheet $samplesheet | tr -d '[],'))
#samples=($(python /proj/phanstiel_lab/software/launch_pipeline/scripts/sample_names.py --samplesheet $samplesheet | tr -d '[],'))
=======
#samples=($(python /pine/scr/n/e/nekramer/sample_names.py --samplesheet $samplesheet | tr -d '[],'))
samples=($(python /proj/phanstiel_lab/software/launch_pipeline/scripts/sample_names.py --samplesheet $samplesheet | tr -d '[],'))
>>>>>>> master
username=$USER
scrspace="/pine/scr/${username:0:1}/${username:1:1}/$username"

for i in $samples; 
	do eval i=$i;
	

	## go through each sample's aligned files and gzip everything except inter_30.txt, merged_nodups.txt, and inter_30.hic
	for filename in $scrspace/$i/aligned/*;
		do
		if [ $(basename $filename) == "inter.txt" ] || [ $(basename $filename) == "merged_nodups.txt" ] || [ $(basename $filename) == "inter_30.hic" ];
 			then continue
 		elif [ -d $filename ];
 			then tar -czvf $filename.tar.gz $filename
			rm -r $filename
 		else
 	 		gzip $filename
 	fi
 done


 	## go through each sample's debug files and gzip everything	
 	for filename in $scrspace/$i/debug/*; do gzip $filename; done

 	project=($(python /proj/phanstiel_lab/software/launch_pipeline/scripts/splitter.py --samplename $i))
 	## Create sample-specific aligned and debug directories in cluster if they do not exist
	if [ ! -d "/proj/phanstiel_lab/Data/processed/$project/hic/$i/aligned" ];
		then mkdir --parents "/proj/phanstiel_lab/Data/processed/$project/hic/$i/aligned"

	fi
	if [ ! -d "/proj/phanstiel_lab/Data/processed/$project/hic/$i/debug" ];
		then mkdir --parents "/proj/phanstiel_lab/Data/processed/$project/hic/$i/debug"
	fi

	## Move and rename desired aligned and debug files to cluster with samplename_filename format
	for filename in $scrspace/$i/aligned/*; do mv $filename "/proj/phanstiel_lab/Data/processed/$project/hic/$i/aligned/${i}_$(basename $filename)"; done
	for filename in $scrspace/$i/debug/*; do mv $filename "/proj/phanstiel_lab/Data/processed/$project/hic/$i/debug/${i}_$(basename $filename)"; done

	## CLEANUP FILES ##

	## Unlink all fastq files
	rm $scrspace/$i/fastq/*

	## Delete empty fastq directory
	rm -r $scrspace/$i/fastq

	## Delete juicer directory
	rm -r $scrspace/$i/juicer

	## Delete everything else
	rm -r $scrspace/$i


done
