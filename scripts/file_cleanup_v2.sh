#!/bin/bash

## FILE COMPRESSION, RENAMING, MOVING, AND CLEANUP ##
samplesheet=$1
finalDir=$2
topDir=$3

samplename=`basename ${topDir}`
homeDir=`dirname ${topDir}`

## go through each sample's aligned files and gzip everything
for filename in ${topDir}/aligned/*;
	do
	if [ -d $filename ];
			then tar -czvf $filename.tar.gz $filename
		rm -r $filename
	else
		gzip $filename
	fi
done

## go through each sample's debug files and gzip everything	
for filename in ${topDir}/debug/*; do gzip $filename; done

## Create sample-specific aligned and debug directories in cluster if they do not exist
if [ ! -d "${finalDir}/aligned" ];
	then mkdir --parents "${finalDir}/aligned"
fi

if [ ! -d "${finalDir}/debug" ];
	then mkdir --parents "${finalDir}/debug"
fi

if [ ! -d "${finalDir}/fastq" ];
	then mkdir --parents "${finalDir}/fastq"
fi

## Move and rename desired aligned and debug files to cluster with samplename_filename format
for filename in ${topDir}/aligned/*; do mv $filename "${finalDir}/aligned/${samplename}_$(basename $filename)"; done
for filename in ${topDir}/debug/*; do mv $filename "${finalDir}/debug/${samplename}_$(basename $filename)"; done
for filename in ${topDir}/fastq/*; do mv $filename "${finalDir}/fastq/"; done
for filename in ${topDir}/*samplesheet.txt; do mv $filename ${finalDir}/; done

## Copy the samplesheets and merge sheets to final directory
for samplesheet in ${homeDir}/*samplesheet.txt; do mv $samplesheet ${finalDir}/; done
for mergesheet in ${homeDir}/*mergeTable.txt; do mv $mergesheet ${finalDir}/; done

## CLEANUP FILES ##
## Delete juicer directory
rm -r ${topDir}/juicer

## Delete everything else
rm -r ${topDir}

