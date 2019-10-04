# Juicer version 1.5.6
shopt -s extglob

## Default options, overridden by command line arguments
# Default queue, can also be set in options with -q/-Q
queue="general"
queue_time="1440"

# Top level directory, can also be set in options with -d
topDir=$(pwd)

# Size to split fastqs - adjust to match your needs, can also be set in options with -C
# 4000000=1M reads per split
splitsize=90000000

# unique name for jobs in this run
groupname="a$(date +%s)"

## Read arguments   
usageHelp="Usage: ${0##*/} [-d topDir] [-q queue] [-C chunk size] [-Q queue time limit] [-h]"
dirHelp="* [topDir] is the top level directory (default\n  \"$topDir\")\n     [topDir]/fastq must contain the fastq files\n     [topDir]/splits will be created to contain the temporary split files\n     [topDir]/aligned will be created for the final alignment"
queueHelp="* [queue] is the queue for running alignments (default \"$queue\")"
queueTimeHelp="* [queue time limit]: time limit for queue, i.e. -W 12:00 is 12 hours\n  (default ${queue_time})"
chunkHelp="* [chunk size]: number of lines in split files, must be multiple of 4\n  (default ${splitsize}, which equals $(awk -v ss=${splitsize} 'BEGIN{print ss/4000000}') million reads)"
emailHelp="* [email]: optional e-mail for a notification of when all the splitting jobs finish running"
helpHelp="* -h: print this help and exit"

printHelpAndExit() {
	echo -e "$usageHelp"
	echo -e "$dirHelp"
	echo -e "$queueHelp"
	echo -e "$queueTimeHelp"
	echo -e "$chunkHelp"
	echo -e "$emailHelp"
	echo "$helpHelp"
	exit "$1"
}

while getopts "d:q:Q:C:e:h" opt; do
	case $opt in
		d) topDir=$OPTARG ;;
		q) queue=$OPTARG ;;
		Q) queue_time=$OPTARG ;;
		C) splitsize=$OPTARG; forceSplit=1 ;;
		e) emailAddress=$OPTARG ;;
		h) printHelpAndExit 0;;
		[?]) printHelpAndExit 1;;
	esac
done

if [ -z $emailAddress ]
	then
		sbatchemail=""
	else
		sbatchemail="#SBATCH --mail-user $emailAddress"
fi

dependsplit="afterok"
jobcount=0
nosplitcount=0
for juicerDirectory in ${topDir}/*
	do
		if [ -d $juicerDirectory ];
			then
				echo "Found juicer directory: $juicerDirectory"
				## Directories to be created and regex strings for listing files
				splitdir=${juicerDirectory}"/splits"
				debugdir=${juicerDirectory}"/debug"
				fastqdir=${juicerDirectory}"/fastq/*_R*.fastq*"

				## Check that fastq directory exists and has proper fastq files
				if [ ! -d "$juicerDirectory/fastq" ]; 
					then
						echo "Directory \"$juicerDirectory/fastq\" does not exist."
						echo "Create \"$juicerDirectory/fastq\" and put fastq files to be aligned there."
						echo "Type \"juicer.sh -h\" for help"
						exit 1
					else 
						if stat -t ${fastqdir} >/dev/null 2>&1
							then
								echo "(-: Looking for fastq files...fastq files exist"
						else
							if [ ! -d "$splitdir" ]
								then 
									echo "***! Failed to find any files matching ${fastqdir}"
									echo "***! Type \"juicer.sh -h \" for help"
									exit 1		
						fi
					fi
				fi

				## Create split directory
				if [ -d "$splitdir" ]; 
					then
						splitdirexists=1
				else
					mkdir "$splitdir" || { echo "***! Unable to create ${splitdir}, check permissions." ; exit 1; }
					echo "(-: Created $splitdir."
				fi

				## Create debug directory, used for reporting commands output
				if [ ! -d "$debugdir" ]; 
					then
						mkdir "$debugdir"
						chmod 777 "$debugdir"
						echo "(-: Created $debugdir."
				fi

				## Arguments have been checked and directories created. Now begins
				## the real work of the pipeline
				# If chunk size sent in, split. Otherwise check size before splitting
				if [ ! -z $forceSplit ]
					then
						splitme=1
				fi

				if [ -z $splitme ]
					then
						fastqsize=$(ls -lL  ${fastqdir} | awk '{sum+=$5}END{print sum}')
						if [ "$fastqsize" -gt "2592410750" ]  
							then
								splitme=1
						fi
				fi

				# Check if the fastq's are gzipped or not
				testname=$(ls -l ${fastqdir} | awk 'NR==1{print $9}')
				if [ "${testname: -3}" == ".gz" ]
					then
						gzipped=1
				fi


				## Split fastq files into smaller portions for parallelizing alignment 
				## Do this by creating a text script file for the job on STDIN and then 
				## sending it to the cluster
				if [ ! $splitdirexists ]
					then
						if [ -n "$splitme" ]
							then
								echo "---  Launching job to split fastqs..."
								for i in ${fastqdir}
									do
										filename=$(basename $i)
										filename=${filename%.*}      
										if [ -z "$gzipped" ]
											then	
												jid=`sbatch <<- SPLITEND | egrep -o -e "\b[0-9]+$"
												#!/bin/bash -l
												#SBATCH -p $queue
												#SBATCH -t $queue_time
												#SBATCH -c 1
												#SBATCH -o $debugdir/split-%j.out
												#SBATCH -e $debugdir/split-%j.err
												#SBATCH -J "${groupname}_split_${i}"
												date
												echo "Split file: $filename"
												split -a 3 -l $splitsize -d --additional-suffix=.fastq $i $splitdir/$filename
												date
SPLITEND`
										dependsplit="$dependsplit:$jid"
										((jobcount++))
										else
											jid=`sbatch <<- SPLITEND | egrep -o -e "\b[0-9]+$"
											#!/bin/bash -l
											#SBATCH -p $queue
											#SBATCH -t $queue_time
											#SBATCH -c 1
											#SBATCH -o $debugdir/split-%j.out
											#SBATCH -e $debugdir/split-%j.err
											#SBATCH -J "${groupname}_split_${i}"
											date
											echo "Split file: $filename"
											zcat $i | split -a 3 -l $splitsize -d --additional-suffix=.fastq - $splitdir/$filename
											date
SPLITEND`
										dependsplit="$dependsplit:$jid"
										((jobcount++))
										fi
									done
							else
								echo "---  No splitting required, moving fastqs over..."
								cp -rs ${fastqdir} ${splitdir}
								wait
								((nosplitcount++))
						fi
				else
					## No need to re-split fastqs if they already exist
					echo -e "---  Using already created files in $splitdir\n"
					((nosplitcount++))
				fi
		fi
	unset splitme
	unset splitdirexists
	done				

if [ $jobcount -ne 0 ]
	then
		jid=`sbatch <<- SPLITDONE | egrep -o -e "\b[0-9]+$"
			#!/bin/bash -l
			#SBATCH -p $queue
			#SBATCH -t $queue_time
			#SBATCH -c 1
			#SBATCH -o $topDir/splitDone-%j.out
			#SBATCH -e $topDir/splitDone-%j.err
			#SBATCH -J "${groupname}_splitProg"
			#SBATCH -d $dependsplit
			#SBATCH --mail-type END,FAIL
			${sbatchemail}
			date
			echo "Splitting has completed! Juicer directories created are here:"
			echo "$topDir"
			echo "=============================="
			echo "CHECKING COMPLETION"
			echo " ---  A valid *samplesheet.txt file (with a JuicerOutputDirectory column)"
			echo " ---  A valid *mergeTable.txt file (one line for every juicer directory here)"
			echo " ---  Non-empty /splits directories within each juicer directory here"
			echo "=============================="
			echo "IN EVENT OF FAILURES"
			echo "If some splits failed for some reason, relaunch by:"
			echo "   1) Deleting the /splits directory for the sample(s) you want to rerun"
			echo "      rm -r $topDir/<failedSample>/splits"
			echo "   2) Moving into the temporary directory"
			echo "      cd $topDir"
			echo "   3) Directly calling the juicer_splitter.sh script"
			echo "      ~/Code/Projects/launch_pipeline/scripts/juicer_splitter.sh"
			echo "=============================="
			echo "TO CONTINUE (LAUNCHING JUICER)"
			echo "   1) Move into the temporary directory created"
			echo "      cd $topDir"
			echo "   2) Run the following command using launch_pipeline:"
			echo "      launch juicer run"
			echo "Good luck!!!! :)"
SPLITDONE`
fi

## Launch job. Once split/move is done, set the parameters for the launch. 
echo "==================================================================="
echo "$jobcount splitting jobs launched!"
echo "$nosplitcount directories did not require splitting."
echo "==================================================================="
echo "CHECKING COMPLETION"
echo "Files output to temporary directory:"
echo "      $topDir"
echo "Make sure this directory has:"
if [ $jobcount -ne 0 ]
	then echo " ---  A splitDone-${jid}.out file to show splits are complete (also contains these instructions)."
fi
echo " ---  A valid *samplesheet.txt file (with a JuicerOutputDirectory column)"
echo " ---  A valid *mergeTable.txt file (one line for every juicer directory here)"
echo " ---  Non-empty /splits directories within each juicer directory here"
echo "==================================================================="
echo "IN EVENT OF FAILURES"
echo "If some splits failed for some reason, relaunch by:"
echo "   1) Deleting the /splits directory for the sample(s) you want to rerun"
echo "      rm -r $topDir/<failedSample>/splits"
echo "   2) Moving into the temporary directory"
echo "      cd $topDir"
echo "   3) Directly calling the juicer_splitter.sh script"
echo "      ~/Code/Projects/launch_pipeline/scripts/juicer_splitter.sh"
echo "==================================================================="
echo "ONCE COMPLETED (LAUNCHING JUICER):"
echo "   1) Move into the temporary directory created:"
echo "      cd $topDir"
echo "   2) Check on your splits files, then launch jucier:"
echo "      launch juicer run"
echo "==================================================================="
echo "Good luck!!! :)"


