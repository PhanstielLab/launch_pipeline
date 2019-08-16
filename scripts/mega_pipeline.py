import pandas as pd
import os
import argparse
import getpass
from namer import namer
import tempfile as temp


megaDir="/proj/phanstiel_lab/software/juicer/scripts/mega.sh"

#INPUTS
#command line inputs
parser = argparse.ArgumentParser(description="Put in samplesheet.")
parser.add_argument("--samplesheet", action = "store", type = str, dest="samplesheet", help = "samplesheet.", required = True)
parser.add_argument("--output", action = "store", type = str, dest="output", help = "path to final output directory.", default = None, required = False)
parser.add_argument("--merge", action = "store", type = str, dest="merge", help = "parameters to merge.", default=None, required = False)
parser.add_argument("--megaOptions", action = "store", type = str, dest = "megaOptions", help = "additional options to pass to mega.sh command.", default = "", required = False)

args = parser.parse_args()

#assign inputs to variables
samplesheet = args.samplesheet
finalDir = args.output
merge = args.merge
megaOptions = args.megaOptions

#find samplesheet
samplesheet_path = os.path.realpath(samplesheet)

#convert samplesheet.txt into pandas dataframe
samples = pd.read_csv(samplesheet_path, sep='\t')

#assume standard samplesheet unless required columns not present
standardSamplesheet = True
requiredColumns = pd.Series(['sample', 'JuicerOutputDir'])
standardColumns = pd.Series(['sample', 'Project', 'Cell_Type', 'Genotype', 'Condition', 'Time',
       'Bio_Rep', 'Tech_Rep', 'Seq_Rep', 'Tag', 'Read1', 'Read2', 'JuicerOutputDir'])

#if standard samplesheet, build default directory structure
if ~requiredColumns.isin(samples.columns).all():
	raise ValueError('Samplesheet requires a "JuicerOutputDir" column, listing the juicer directories for each sample.')

if standardColumns.isin(samples.columns).all(): 

	#fail if more than one project listed
	if len(list(set(samples["Project"]))) > 1: 
		raise ValueError('Multiple projects listed in samplesheet. Only one project is allowed for default output directory.') 

	#set project, default output directory 
	project = list(set(samples["Project"]))[0]
	finalDir = "/proj/phanstiel_lab/Data/processed/" + project + "/hic/" + namer(samples, ['Project', 'Cell_Type', 'Genotype', 'Condition', 'Time'],['Tag'],['Bio_Rep', 'Tech_Rep', 'Seq_Rep'])
else:

	#if non-standard, no project name and required path provided by --output
	standardSamplesheet = False
	print('Non-standard samplesheet provided. Default directory structure not used.')
	project = ""
	if finalDir == None:
		raise ValueError('Please provide a path to output directory when using a non-standard samplesheet.')

#get username information to put jobs in scr space
username = getpass.getuser()
scrspace = "/pine/scr/"+username[0]+"/"+username[1]+"/"+username

#make temp directory in scr space for running the code
scratchDir = temp.mkdtemp(prefix='hicMegaMap-' + project, dir=scrspace)

#MERGE
#set default merge for standard samplesheets
if standardSamplesheet == True and merge == None:
	merge = 'Project,Cell_Type,Genotype,Condition,Time,Tag'

#create merged sample list
if merge is not None:	
	mergeEntries = str.split(merge, sep=",")
	for columnName in mergeEntries:
		if columnName not in samples.columns:
			raise ValueError('Columns listed for merging do not exist in samplesheet provided.')

	#launch the merging R script and read in the output as a pandas dataframe 
	os.system("Rscript /proj/phanstiel_lab/software/launch_pipeline/scripts/merge.R " + samplesheet_path + " " + scratchDir + "/mergeTable.txt " + " ".join(mergeEntries))
	mergedSamples = pd.read_csv(scratchDir + "/mergeTable.txt", sep='\t')
else:
	#if non-standard sheet and no merge option listed, make a fake mergedSample list with each sample on its own row
	mergedSamples = pd.DataFrame({'MergeName':samples["sample"], 'Sample_1':samples["sample"]})

#BUILD DIRECTORIES
#extract full list of samples from original samplesheet
fullSampleList = samples['sample']

#for each merge group, build it's own juicer directory, put fastqs from all samples into it, and launch juicer
for mergeGroupIdx in mergedSamples.index:

	#pull the sample names from the merge group (row of mergedSamples)
	mergeSampleList = list(mergedSamples.iloc[mergeGroupIdx][1:])

	#subset the original samplesheet for the samples in that merge group
	mergeDataframe = samples[fullSampleList.isin(mergeSampleList)]

	#if you're using a standard samplesheet, make a better name for the merge group
	if standardSamplesheet == True:
		mergeName = namer(mergeDataframe, ['Project', 'Cell_Type', 'Genotype', 'Condition', 'Time'],['Tag'],['Bio_Rep', 'Tech_Rep', 'Seq_Rep'])
		mergedSamples.iloc[mergeGroupIdx][0] = mergeName
	else:
		mergeName = mergedSamples.iloc[mergeGroupIdx][0]
	
	#make mega directory for merge group
	os.mkdir(scratchDir+"/"+mergeName+"_megaMap")

	#within that directory, make it's own fastq directory
	os.mkdir(scratchDir+"/"+mergeName+"_megaMap/fastq")

	#write subset samplesheet to merge group directory, for juicer.sh input (cleanup)
	mergeDataframe.to_csv(scratchDir + "/" + mergeName + "_megaMap/" + mergeName + "_MegaMapSamplesheet.txt", sep="\t", index=False)

	#subset for unique juicer directories to get list of directories to be linked together
	directoryList = mergeDataframe[]

	#for each sample in that merge set
	for sampleIdx in mergeDataframe.index:
		samplename = mergeDataframe["JuicerOutputDir"][sampleIdx]

		#get paths to reads for fastqs
		read1_source = mergeDataframe["Read1"][sampleIdx]
		read2_source = mergeDataframe["Read2"][sampleIdx]
		
		#designate destination and name for links
		read1_dest = scratchDir+"/"+mergeName+"_megaMap/fastq/"+os.path.basename(read1_source)
		read2_dest = scratchDir+"/"+mergeName+"_megaMap/fastq/"+os.path.basename(read2_source)

		#create links to fastqs
		os.symlink(read1_source, read1_dest)
		os.symlink(read2_source, read2_dest)

	#make juicer directory
	os.mkdir(scratchDir+"/"+mergeName+"_megaMap/juicer")

	#link juicer software files
	os.symlink(juicerDir, scratchDir+"/"+mergeName+"_megaMap/juicer/scripts")

	#RUN JUICER
	#go into sample directory
	os.chdir(scratchDir+"/"+mergeName+"_megaMap")

	#run juicer from within it
	os.system("./juicer/scripts/juicer.sh " + scratchDir + "/" + mergeName + "_megaMap/" + mergeName + "_samplesheet.txt " + finalDir + " " + juicerOptions)

	#go back to scratchspace
	os.chdir(scratchDir)

#overwrite the original merge file with the renamed merged file
mergedSamples.to_csv(scratchDir + "/mergeTable.txt", sep="\t", index=False)

