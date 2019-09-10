#!/bin/bash
##########
#The MIT License (MIT)
#
# Copyright (c) 2015 Aiden Lab
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
#  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
#  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
#  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
#  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
#  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
#  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
#  THE SOFTWARE.
##########
# MegaMap script. 
#
#                                                                       
# [topDir]		    - Should contain the results of all base experiments
#
# From the top-level directory, the following two directory is created:
#                                                                              
# [topDir]/mega     - Location of result of processing the mega map
#
# Juicer version 1.5
juicer_version="1.5.6" 
## Set the following variables to work with your system

unset MALLOC_ARENA_MAX
load_bwa="module load bwa"
load_gpu="CUDA_VISIBLE_DEVICES=0,1,2,3"
# Juicer directory, contains scripts/, references/, and restriction_sites/
# can also be set in options via -D
juiceDir="/proj/phanstiel_lab/software/juicer/"
# default queue, can also be set in options
queue="general"
queue_time="1440"
# default long queue, can also be set in options
long_queue="general"
long_queue_time="10080"

# Aiden Lab specific check
isRice=$(hostname | awk '{if ($1~/rice/){print 1}else {print 0}}')
isBCM=$(hostname | awk '{if ($1~/bcm/){print 1}else {print 0}}')
isVoltron=0
## path additionals, make sure paths are correct for your system
## use cluster load commands
if [ $isRice -eq 1 ] 
then
		myPath=/bin:$PATH 
		load_bwa="module load bwa" 
		load_java="module load java" 
		load_gpu="CUDA_VISIBLE_DEVICES=0,1,2,3" 
		# Juicer directory, contains scripts/, references/, and restriction_sites/
		# can also be set in options via -D
		juiceDir="/proj/phanstiel_lab/software/juicer/" ### RICE
		# default queue, can also be set in options via -q
		queue="general"
		# default long queue, can also be set in options via -l
		long_queue="general"
		long_queue_time="10080"
elif [ $isBCM -eq 1 ]
then    
		# Juicer directory, contains scripts/, references/, and restriction_sites/
		# can also be set in options via -D
		juiceDir="/proj/phanstiel_lab/software/juicer/"
		# default queue, can also be set in options via -q
		queue="general"
		queue_time="1440"
		# default long queue, can also be set in options via -l
		long_queue="general"
		long_queue_time="10080"
else
		isVoltron=1
		#export PATH=/gpfs0/biobuild/biobuilds-2016.11/bin:$PATH 
		unset MALLOC_ARENA_MAX
		load_gpu="CUDA_VISIBLE_DEVICES=0,1,2,3"
		# Juicer directory, contains scripts/, references/, and restriction_sites/
		# can also be set in options via -D
		juiceDir="/proj/phanstiel_lab/software/juicer/"
		# default queue, can also be set in options
		queue="general"
		# default long queue, can also be set in options
		long_queue="general"
		long_queue_time="10080"
fi

# unique name for jobs in this run
groupname="a$(date +%s)"

## Default options, overridden by command line arguments

# top level directory, can also be set in options
topDir=$(pwd)
# restriction enzyme, can also be set in options
site="MboI"
# genome ID, default to human, can also be set in options
genomeID="hg19"

## Read arguments                                                     
usageHelp="Usage: ${0##*/} -g genomeID [-d topDir] [-s site] [-S stage] [-q queue] [-l long queue] [-Q queue time] [-L long queue time] [-x] [-h]"
genomeHelp="   genomeID must be defined in the script, e.g. \"hg19\" or \"mm10\" (default \"$genomeID\")"
dirHelp="   [topDir] is the top level directory (default \"$topDir\") and must contain links to all merged_nodups files underneath it"
siteHelp="   [site] must be defined in the script, e.g.  \"HindIII\" or \"MboI\" (default \"$site\"); alternatively, this can be the restriction site file"
stageHelp="* [stage]: must be one of \"final\", \"postproc\", or \"early\".\n    -Use \"final\" when the reads have been combined into merged_nodups but the\n     final stats and hic files have not yet been created.\n    -Use \"postproc\" when the hic files have been created and only\n     postprocessing feature annotation remains to be completed.\n    -Use \"early\" for an early exit, before the final creation of the stats and\n     hic files"
excludeHelp="   -x: exclude fragment-delimited maps from Hi-C mega map (will run much faster)"
pipelineHelp="   [pipeline output directory]: use when running as part of the Phanstiel Lab mega_pipeline.py script; toggles cleanup job, moves files to designated destination"
helpHelp="   -h: print this help and exit"

printHelpAndExit() {
		echo "$usageHelp"
		echo "$genomeHelp"
		echo "$dirHelp"
		echo "$siteHelp"
		echo "$stageHelp"
		echo "$excludeHelp"
		echo "$pipelineHelp"
		echo "$helpHelp"
		exit "$1"
}

while getopts "d:g:hxs:S:l:L:q:Q:P:" opt; do
		case $opt in
	g) genomeID=$OPTARG ;;
	h) printHelpAndExit 0;;
	d) topDir=$OPTARG ;;
	s) site=$OPTARG ;;
	x) exclude=1 ;;
	S) stage=$OPTARG ;;
	l) long_queue=$OPTARG ;;
	L) long_queue_time=$OPTARG ;;
	q) queue=$OPTARG ;;
	Q) queue_time=$OPTARG ;;
	P) pipeline=$OPTARG ;;
	[?]) printHelpAndExit 1;;
		esac
done

## Set ligation junction based on restriction enzyme
case $site in
		HindIII) ligation="AAGCTAGCTT";;
		DpnII) ligation="GATCGATC";;
		MboI) ligation="GATCGATC";;
		none) ligation="XXXX";;
		*)  ligation="XXXX"
	site_file=$site
	echo "$site not listed as recognized enzyme, so trying it as site file."
	echo "Ligation junction is undefined";;
esac

if [ -z "$site_file" ]
then
		site_file="${juiceDir}/restriction_sites/${genomeID}_${site}.txt"
fi

## Check that site file exists, needed for fragment number for merged_nodups
if [ ! -e "$site_file" ] && [ "$site" != "none" ]
then
		echo "***! $site_file does not exist. It must be created before running this script."
		echo "The site file is used for statistics even if fragment delimited maps are excluded"
		exit 1
fi

if [ ! -z "$stage" ]
then
		case $stage in
				final) final=1 ;;
	early) early=1 ;;
	postproc) postproc=1 ;;
				*)  echo "$usageHelp"
			echo "$stageHelp"
			exit 1
		esac
fi

## Directories to be created and regex strings for listing files
megadir=${topDir}"/mega"
outputdir=${megadir}"/aligned"
tmpdir=${megadir}"/HIC_tmp"
export TMPDIR=${tmpdir}
outfile=${megadir}/lsf.out
#output messages
logdir="$megadir/debug"
touchfile1=${megadir}/touch1
touchfile2=${megadir}/touch2
touchfile3=${megadir}/touch3
touchfile4=${megadir}/touch4
touchfile5=${megadir}/touch5
touchfile6=${megadir}/touch6
touchfile7=${megadir}/touch7
touchfile8=${megadir}/touch8

## Check for existing merged_nodups files:

merged_count=`find -L ${topDir} | grep merged_nodups.txt | wc -l`
if [ "$merged_count" -lt "1" ]
then
	echo "***! Failed to find at least one merged_nodups files under ${topDir}"
	exit 1
fi

# merged_names=$(find -L ${topDir} | grep merged_nodups.txt.gz | awk '{print "<(gunzip -c",$1")"}' | tr '\n' ' ')
# if [ ${#merged_names} -eq 0 ]
# then
# 		merged_names=$(find -L ${topDir} | grep merged_nodups.txt | tr '\n' ' ')
# fi

merged_names=$(find -L ${topDir} | grep merged_nodups.txt | tr '\n' ' ')
echo "merged files found: ${merged_names}"

inter_names=$(find -L ${topDir} | grep inter.txt | tr '\n' ' ')
echo "stats files found: ${inter_names}"

zipped_names=''

for file in $merged_names
	do if [ ${file: -3} == ".gz" ]
		then zipped_names="${zipped_names} ${file}"
	fi
done

for file in $inter_names
	do if [ ${file: -3} == ".gz" ]
		then zipped_names="${zipped_names} ${file}"
	fi
done

echo "zipped files found: ${zipped_names}"

if [ ! -z "$zipped_names" ]
	then
		jid0=`sbatch <<- UNZIP | egrep -o -e "\b[0-9]+$"
		#!/bin/bash
		#SBATCH -p $queue
		#SBATCH -t 1200
		#SBATCH --mem-per-cpu=2G
		#SBATCH -o $logdir/unzip-%j.out
		#SBATCH -e $logdir/unzip-%j.err
		#SBATCH -J "UNZIP_${groupname}"
		gunzip $zipped_names
		UNZIP`

		dependunzip="#SBATCH -d afterok:$jid0"

		merged_names=${merged_names//.txt.gz/.txt}

		inter_names=${inter_names//.txt.gz/.txt}

	else
		dependunzip=""
fi

echo "dependunzip: $dependunzip"
echo "Unzipped merged files: ${merged_names}"
echo "Unzipped stats files: ${inter_names}"

## Create output directory, exit if already exists
if [[ -d "${outputdir}" ]] && [ -z $final ] && [ -z $postproc ]
then
		echo "***! Move or remove directory \"${outputdir}\" before proceeding."
	exit 101			
else
	mkdir -p ${outputdir}
fi

## Create temporary directory
if [ ! -d "$tmpdir" ]; then
		mkdir $tmpdir
		chmod 777 $tmpdir
fi

## Create output directory, used for reporting commands output
if [ ! -d "$logdir" ]; then
				mkdir "$logdir"
				chmod 777 "$logdir"
fi

## Arguments have been checked and directories created. Now begins
## the real work of the pipeline

# Not in final or postproc
if [ -z $final ] && [ -z $postproc ]
then
# Create top statistics file from all inter.txt files found under current dir

jid1=`sbatch <<- TOPSTATS | egrep -o -e "\b[0-9]+$"
#!/bin/bash -l
#SBATCH -p $queue
#SBATCH -t 1440
#SBATCH -c 1
#SBATCH --ntasks=1
#SBATCH -o $logdir/topstats-%j.out
#SBATCH -e $logdir/topstats-%j.err
#SBATCH -J "${groupname}_topstats"
#SBATCH --mem-per-cpu=4G 
$dependunzip
export LC_COLLATE=C
if ! awk -f ${juiceDir}/scripts/makemega_addstats.awk ${inter_names} > ${outputdir}/inter.txt
then  
		echo "***! Some problems occurred somewhere in creating top stats files."
		exit 100
else
		echo "(-: Finished creating top stats files."
		cp ${outputdir}/inter.txt ${outputdir}/inter_30.txt
fi
touch $touchfile1
TOPSTATS`
		dependtopstats="afterok:$jid1"
		echo "Depend for Topstats: $dependunzip"
# Merge all merged_nodups.txt files found under current dir
		jid2=`sbatch <<- MRGSRT | egrep -o -e "\b[0-9]+$"
#!/bin/bash -l
#SBATCH -p ${long_queue}
#SBATCH -t ${long_queue_time}
#SBATCH -c 1
#SBATCH --ntasks=1
#SBATCH -o $logdir/merge-%j.out
#SBATCH -e $logdir/merge-%j.err
#SBATCH -J "${groupname}_merge"
#SBATCH -d "${dependtopstats}"
#SBATCH --mem-per-cpu=8G
if [ ! -f "${touchfile1}" ]
then
		echo "***! Top stats job failed, type \"scontrol show job $jid1\" to see what happened."
		exit 1
fi

	if [ $isRice -eq 1 ]
	then
		if ! ${juiceDir}/scripts/sort --parallel=48 -S8G -T ${tmpdir} -m -k2,2d -k6,6d ${merged_names} > ${outputdir}/merged_nodups.txt
		then
			echo "***! Some problems occurred somewhere in creating sorted merged_nodups files."
			exit 1
		fi
	else
		if ! sort --parallel=40 -T ${tmpdir} -m -k2,2d -k6,6d ${merged_names} > ${outputdir}/merged_nodups.txt
		then 
			echo "***! Some problems occurred somewhere in creating sorted merged_nodups files."
			exit 1
		else
			echo "(-: Finished sorting all merged_nodups files into a single merge."
			rm -r ${tmpdir}
		fi
	fi
touch $touchfile2
MRGSRT`
		dependmerge="#SBATCH -d afterok:$jid2"
		echo "Depend for Merge: $dependtopstats"
else
		touch $touchfile1
		touch $touchfile2
fi

if [ -z $postproc ] && [ -z $early ]
then
		# Create statistics files for MQ > 0
		jid3=`sbatch <<- INTER0 | egrep -o -e "\b[0-9]+$"
#!/bin/bash -l
#SBATCH -p ${long_queue}
#SBATCH -t ${long_queue_time}
#SBATCH -c 1
#SBATCH --ntasks=1
#SBATCH -o $logdir/inter0-%j.out
#SBATCH -e $logdir/inter0-%j.err
#SBATCH -J "${groupname}_inter0"
#SBATCH --mem-per-cpu=2G
${dependmerge}
if [ ! -f "${touchfile2}" ]
then
	 echo "***! Sort job failed."
	 exit 1
fi
if ${juiceDir}/scripts/statistics.pl -q 1 -o${outputdir}/inter.txt -s $site_file -l $ligation ${outputdir}/merged_nodups.txt
then
	 touch $touchfile3
fi
INTER0`
		echo "Depend for Inter0: $dependmerge"
		dependinter0="afterok:$jid3"

		# Create statistics files for MQ > 30
		jid4=`sbatch <<- INTER30 | egrep -o -e "\b[0-9]+$"
#!/bin/bash -l
#SBATCH -p ${long_queue}
#SBATCH -t ${long_queue_time}
#SBATCH -c 1
#SBATCH --ntasks=1
#SBATCH -o $logdir/inter30-%j.out
#SBATCH -e $logdir/inter30-%j.err
#SBATCH -J "${groupname}_inter30"
#SBATCH --mem-per-cpu=2G 
${dependmerge}
if [ ! -f "${touchfile2}" ]
then
	 echo "***! Sort job failed."
	 exit 1
fi
if ${juiceDir}/scripts/statistics.pl -q 30 -o${outputdir}/inter_30.txt -s $site_file -l $ligation ${outputdir}/merged_nodups.txt 
then
	touch $touchfile4
fi
INTER30`
		dependinter30="afterok:$jid4"
		echo "Depend for Inter30: $dependmerge"

		# Create HIC maps file for MQ > 0
		jid5=`sbatch <<- HIC0 | egrep -o -e "\b[0-9]+$"
#!/bin/bash -l
#SBATCH -p ${long_queue}
#SBATCH -t ${long_queue_time}
#SBATCH -c 8
#SBATCH --ntasks=1
#SBATCH -o $logdir/hic0-%j.out
#SBATCH -e $logdir/hic0-%j.err
#SBATCH -J "${groupname}_hic0"
#SBATCH -d "${dependinter0}"
#SBATCH --mem=73G
#source $usePath
$load_java
export IBM_JAVA_OPTIONS="-Xmx73728m -Xgcthreads1"
if [ ! -f "${touchfile3}" ]
then
	 echo "***! Statistics q=1 job failed."
	 exit 1
fi
if [ -z "$exclude" ] &&  ${juiceDir}/scripts/juicer_tools72g pre -f ${site_file} -s ${outputdir}/inter.txt -g ${outputdir}/inter_hists.m -q 1 ${outputdir}/merged_nodups.txt ${outputdir}/inter.hic ${genomeID} 
then
	 touch $touchfile5
elif [ -n "$exclude" ] &&  ${juiceDir}/scripts/juicer_tools72g pre -s ${outputdir}/inter.txt -g ${outputdir}/inter_hists.m -q 1 ${outputdir}/merged_nodups.txt ${outputdir}/inter.hic ${genomeID} 
then
	 touch $touchfile5 
fi
HIC0`
		dependhic0="afterok:$jid5"
		echo "Depend for HiC0: $dependinter0"

		# Create HIC maps file for MQ > 30
		jid6=`sbatch <<- HIC30 | egrep -o -e "\b[0-9]+$"
#!/bin/bash -l
#SBATCH -p ${long_queue}
#SBATCH -t ${long_queue_time}
#SBATCH -c 1
#SBATCH --ntasks=1
#SBATCH -o $logdir/hic30-%j.out
#SBATCH -e $logdir/hic30-%j.err
#SBATCH -J "${groupname}_hic30"
#SBATCH -d "${dependinter30}"
#SBATCH --mem=73G
#source $usePath
$load_java	
export IBM_JAVA_OPTIONS="-Xmx73728m -Xgcthreads1"
if [ ! -f "${touchfile4}" ]
then
	 echo "***! Statistics q=30 job failed."
	 exit 1
fi
if [ -z "${exclude}" ] &&  ${juiceDir}/scripts/juicer_tools72g pre -f ${site_file} -s ${outputdir}/inter_30.txt -g ${outputdir}/inter_30_hists.m -q 30 ${outputdir}/merged_nodups.txt ${outputdir}/inter_30.hic ${genomeID} 
then
	 touch $touchfile6
elif [ -n "${exclude}" ] && ${juiceDir}/scripts/juicer_tools72g pre -s ${outputdir}/inter_30.txt -g ${outputdir}/inter_30_hists.m -q 30 ${outputdir}/merged_nodups.txt ${outputdir}/inter_30.hic ${genomeID} 
then
	 touch $touchfile6
fi
HIC30`
echo "Depend for HiC30: $dependinter30"
		dependhic30only="afterok:$jid6"
		sbatchdepend="#SBATCH -d ${dependhic30only}"
		dependhic30="${dependhic0}:$jid6"
else
		touch $touchfile3 $touchfile4 $touchfile5 $touchfile6
		sbatchdepend=""
fi

if [ -z $early ]
then
# Create loop lists file for MQ > 30
		touchfile7=${megadir}/touch7
		if [ $isRice -eq 1 ] || [ $isVoltron -eq 1 ]
		then
	if [  $isRice -eq 1 ]
	then
			sbatch_req="#SBATCH --gres=gpu:kepler:1"
	fi
	jid7=`sbatch <<- HICCUPS | egrep -o -e "\b[0-9]+$"
	#!/bin/bash -l
	#SBATCH -p gpu
	#SBATCH --gres=gpu:1
	#SBATCH --qos gpu_access
	#SBATCH -t 1440
	#SBATCH --ntasks=1
	#SBATCH --mem-per-cpu=12G 
	#SBATCH -o $logdir/hiccups-%j.out
	#SBATCH -e $logdir/hiccups-%j.err
	#SBATCH -J "${groupname}_hiccups"
	${sbatchdepend}
	${load_gpu}
	$load_java
	if [ ! -f "${touchfile6}" ]
	then
		 echo "***! HIC maps q=30 job failed."
		 exit 1
	fi
	${juiceDir}/scripts/juicer_hiccups.sh -j ${juiceDir}/scripts/juicer_tools -i $outputdir/inter_30.hic -m ${juiceDir}/references/motif -g $genomeID
	touch $touchfile7
	HICCUPS`
	echo "Depend for hiccups: $sbatchdepend"
	dependhic30="${dependhic30}:$jid7"
		else
	touch $touchfile7
		fi

		touchfile8=${megadir}/touch8
		# Create domain lists for MQ > 30
		jid8=`sbatch <<- ARROWHEAD | egrep -o -e "\b[0-9]+$"
#!/bin/bash -l
#SBATCH -p ${long_queue}
#SBATCH -t ${long_queue_time}
#SBATCH -c 2
#SBATCH --ntasks=1
#SBATCH --mem-per-cpu=16G 
#SBATCH -o $logdir/arrowhead-%j.out
#SBATCH -e $logdir/arrowhead-%j.err
#SBATCH -J "${groupname}_arrowhead"
${sbatchdepend}
$load_java	
if [ ! -f "${touchfile6}" ]
then
	 echo "***! HIC maps q=30 job failed."
	 exit 1
fi
${juiceDir}/scripts/juicer_arrowhead.sh -j ${juiceDir}/scripts/juicer_tools72g -i $outputdir/inter_30.hic
touch $touchfile8
ARROWHEAD`
echo "Depend for arrowhead: $sbatchdepend"
		dependhic30="${dependhic0}:$jid8"
		# Final checks
		jid9=`sbatch <<- FINAL | egrep -o -e "\b[0-9]+$"
#!/bin/bash -l
#SBATCH -p ${queue}
#SBATCH -t 100
#SBATCH -c 1
#SBATCH --ntasks=1
#SBATCH -o $logdir/done-%j.out
#SBATCH -e $logdir/done-%j.err
#SBATCH -J "${groupname}_done"
#SBATCH -d "${dependhic30}"

if [ ! -f "${touchfile5}" ]
then
	 echo "***! Failed to make inter.hic."   
	 exit 1
fi
if [ ! -f "${touchfile6}" ]
then
	 echo "***! Failed to make inter_30.hic."   
	 exit 1
fi
if [ ! -f "${touchfile7}" ]
then
	 echo "***! Failed to create loop lists."   
	 exit 1
fi
if [ ! -f "${touchfile8}" ]
then
	 echo "***! Failed to create domain lists."   
	 exit 1
fi
rm -r ${tmpdir}
rm $touchfile1 $touchfile2 $touchfile3 $touchfile4 $touchfile5 $touchfile6 $touchfile7 $touchfile8
echo "(-: Successfully completed making mega map. Done. :-)"
if [ $isRice -eq 1 ]
then
	 echo $topDir, $site, $genomeID, $genomePath | mail -r MegaJuicer@rice.edu -s \"Mega Juicer pipeline finished successfully @ Rice\" -t $USER@rice.edu;
fi
FINAL`
echo "Depend for Done: $dependhic30"
dependfinish="${dependmerge}:$jid9"
else
		jid9=`sbatch <<- FINAL | egrep -o -e "\b[0-9]+$"
#!/bin/bash -l
#SBATCH -p ${queue}
#SBATCH -t 100
#SBATCH -c 1
#SBATCH --ntasks=1
#SBATCH -o $logdir/done-%j.out
#SBATCH -e $logdir/done-%j.err
#SBATCH -J "${groupname}_done"
#SBATCH -d "${dependmerge}"

rm -r ${tmpdir}
rm -f $touchfile1 $touchfile2 $touchfile3 $touchfile4 $touchfile5 $touchfile6 $touchfile7 $touchfile8
echo "(-: Successfully completed making mega map. Done. :-)"
FINAL`
echo "Depend for Done: $dependmerge"
dependfinish="${dependmerge}:$jid9"
fi

if [ ! -z "$pipeline" ]
then
	echo "Final pipeline output directory: ${pipeline}"
	jid=`sbatch <<- CLEANUP | egrep -o -e "\b[0-9]+$"
		#!/bin/bash
		#SBATCH -p $queue
		#SBATCH -t 1200
		#SBATCH --mem-per-cpu=2G
		#SBATCH -o $logdir/cleanup-%j.out
		#SBATCH -e $logdir/cleanup-%j.err
		#SBATCH -J "CLEANUP_${groupname}"
		${dependfinish}
		/nas/longleaf/home/ksmetz/testingJuicerPipe/scripts/file_cleanup_mega.sh ${pipeline}
	CLEANUP`
fi
echo "Depend for Cleanup: $dependfinish"
echo "(-: Finished adding all jobs... please wait while processing."


