#!/bin/bash

## FILE COMPRESSION, RENAMING, MOVING, AND CLEANUP ##
finalDir=$1
topDir=$(pwd)

samplename=$(basename "$topDir")
homeDir=$(dirname "$topDir")

echo "Moving to: ${finalDir}"

## go through each sample's aligned files and gzip everything
echo "Zipping aligned files..."
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
echo "Zipping debug files..."
for filename in ${topDir}/debug/*; do gzip $filename; done

## Create sample-specific aligned and debug directories in cluster if they do not exist
echo "Making output directories..."
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
echo "Moving files..."
for filename in ${topDir}/aligned/*; do mv $filename "${finalDir}/aligned/${samplename}_$(basename $filename)"; done
for filename in ${topDir}/debug/*; do mv $filename "${finalDir}/debug/${samplename}_$(basename $filename)"; done
for filename in ${topDir}/fastq/*; do mv $filename "${finalDir}/fastq/"; done
for filename in ${topDir}/*samplesheet.txt; do mv $filename ${finalDir}/; done

## Copy the samplesheets and merge sheets to final directory
for samplesheet in ${homeDir}/*samplesheet.txt; do cp $samplesheet $(dirname "$finalDir")/; done
for mergesheet in ${homeDir}/*mergeTable.txt; do cp $mergesheet $(dirname "$finalDir")/; done

## CLEANUP FILES ##
## Delete juicer directory
rm -r ${topDir}/juicer

## Delete splits directory
rm -r ${topDir}/splits

# ## Delete everything else
# rm -r ${topDir}

