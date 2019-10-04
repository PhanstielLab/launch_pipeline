import pandas as pd
import os
import argparse
import getpass
from namer import namer
import tempfile as temp


juicerDir="/proj/phanstiel_lab/software/juicer/scripts/"
#juicerDir="/nas/longleaf/home/ksmetz/testingJuicerPipe/juicer/scripts"

#INPUTS
#command line inputs
parser = argparse.ArgumentParser(description="Put in samplesheet.")
parser.add_argument("--samplesheet", action = "store", type = str, dest="samplesheet", help = "Samplesheet (tab-delimited).", required = True)
parser.add_argument("--output", action = "store", type = str, dest="output", help = "Path to final output directory.", default = None, required = False)
parser.add_argument("--merge", action = "store", type = str, dest="merge", help = "Parameters to merge.", default=None, required = False)
parser.add_argument("--email", action = "store", type = str, dest = "email", help = "E-mail address for notifications of splitting job progress (optional).", default = "", required = False)
parser.add_argument("--splitterOptions", action = "store", type = str, dest = "splitterOptions", help = "Additional options to pass to splitter script.", default = "", required = False)

args = parser.parse_args()

#assign inputs to variables
samplesheet = args.samplesheet
finalDir = args.output
merge = args.merge
email = args.email
splitterOptions = args.splitterOptions

#if an e-mail address was provided, fit it into a command for splitter script
if email is not "":
	email=" -e " + email + " "

#find samplesheet
samplesheet_path = os.path.realpath(samplesheet)

#convert samplesheet.txt into pandas dataframe
samples = pd.read_csv(samplesheet_path,  sep='\t', nrows=1) # Just take the first row to extract the columns' names
col_str_dic = {column:str for column in list(samples)} 		# Make sure you're reading everything as a string!!!
samples = pd.read_csv(samplesheet_path, sep='\t', dtype=col_str_dic)

#add empty "JuicerOutputDir" column to populate during script
samples["JuicerOutputDir"] = [""] * len(samples)

#assume standard samplesheet unless required columns not present
standardSamplesheet = True
requiredColumns = pd.Series(['sample', 'Project', 'Cell_Type', 'Genotype', 'Condition', 'Time',
       'Bio_Rep', 'Tech_Rep', 'Seq_Rep', 'Tag', 'Read1', 'Read2'])

#if standard samplesheet, build default directory structure
if requiredColumns.isin(samples.columns).all(): 

	#fail if more than one project listed
	if len(list(set(samples["Project"]))) > 1: 
		raise ValueError('Multiple projects listed in samplesheet. Only one project is allowed for default output directory.') 

	#set project, default output directory 
	project = list(set(samples["Project"]))[0]
	if finalDir == None:
		finalDir = "/proj/phanstiel_lab/Data/processed/" + project + "/hic/"

	#make combined name for sample sheet, merge sheet
	combinedName = namer(samples, ['Project', 'Cell_Type', 'Genotype', 'Condition', 'Time'],['Tag'],['Bio_Rep', 'Tech_Rep', 'Seq_Rep']) + "_"
else:

	#if non-standard, no project name and required path provided by --output
	standardSamplesheet = False
	print('Non-standard samplesheet provided. Default directory structure not used.')
	project = ""
	if finalDir == None:
		raise ValueError('Please provide a path to output directory when using a non-standard samplesheet.')
	combinedName = ""


#get username information to put jobs in scr space
username = getpass.getuser()
scrspace = "/pine/scr/"+username[0]+"/"+username[1]+"/"+username

#make temp directory in scr space for running the code
scratchDir = temp.mkdtemp(prefix='hic-' + project, dir=scrspace)

#MERGE
#set default merge for standard samplesheets
if standardSamplesheet == True and merge == None:
	merge = 'Project,Cell_Type,Genotype,Condition,Time,Bio_Rep,Tech_Rep,Tag'

#create merged sample list
if merge is not None:	
	mergeEntries = str.split(merge, sep=",")
	for columnName in mergeEntries:
		if columnName not in samples.columns:
			raise ValueError('Columns listed for merging do not exist in samplesheet provided.')

	#launch the merging R script and read in the output as a pandas dataframe 
	os.system("Rscript /proj/phanstiel_lab/software/launch_pipeline/scripts/merge.R " + samplesheet_path + " " + scratchDir + "/" + combinedName + "mergeTable.txt " + " ".join(mergeEntries))
	#os.system("Rscript /nas/longleaf/home/ksmetz/testingJuicerPipe/scripts/merge.R " + samplesheet_path + " " + scratchDir + "/" + combinedName + "mergeTable.txt " + " ".join(mergeEntries))
	mergedSamples = pd.read_csv(scratchDir + "/" + combinedName + "mergeTable.txt", sep='\t')
else:
	#if non-standard sheet and no merge option listed, make a fake mergedSample list with each sample on its own row
	mergedSamples = pd.DataFrame({'MergeName':samples["sample"], 'Sample_1':samples["sample"]})

#add empty "JuicerOutputDir" column to populate during script
mergedSamples["JuicerOutputDir"] = [""] * len(mergedSamples)

#BUILD DIRECTORIES
#extract full list of samples from original samplesheet
fullSampleList = samples['sample']

#for each merge group, build it's own juicer directory, put fastqs from all samples into it, and launch juicer
for mergeGroupIdx in mergedSamples.index:

	#pull the sample names from the merge group (row of mergedSamples)
	mergeSampleList = list(mergedSamples.iloc[mergeGroupIdx,1:])

	#subset the original samplesheet for the samples in that merge group
	mergeDataframe = samples[fullSampleList.isin(mergeSampleList)]

	#if you're using a standard samplesheet, make a better name for the merge group
	if standardSamplesheet == True:
		mergeName = namer(mergeDataframe, ['Project', 'Cell_Type', 'Genotype', 'Condition', 'Time'],['Tag'],['Bio_Rep', 'Tech_Rep', 'Seq_Rep'])
		mergedSamples.loc[mergeGroupIdx, "MergeName"] = mergeName
	else:
		mergeName = mergedSamples.loc[mergeGroupIdx, "MergeName"]
	
	#add FINAL juicer directory to new "JuicerOutputDir" column in samplesheet, for all samples in this merge group
	samples.loc[fullSampleList.isin(mergeSampleList), "JuicerOutputDir"] = finalDir+"/"+mergeName
	mergedSamples.loc[mergeGroupIdx, "JuicerOutputDir"] = finalDir+"/"+mergeName

	#make juicer directory in scratch space for merge group
	os.mkdir(scratchDir+"/"+mergeName)

	#within that directory, make it's own fastq directory
	os.mkdir(scratchDir+"/"+mergeName+"/fastq")

	#write subset samplesheet to merge group directory
	mergeDataframe.to_csv(scratchDir + "/" + mergeName + "/" + mergeName + "_samplesheet.txt", sep="\t", index=False)

	#for each sample in that merge set
	for sampleIdx in mergeDataframe.index:
		samplename = mergeDataframe.loc[sampleIdx,"sample"]

		#get paths to reads for fastqs
		read1_source = mergeDataframe.loc[sampleIdx,"Read1"]
		read2_source = mergeDataframe.loc[sampleIdx,"Read2"]

		#check if they have the right format
		read1_filename = os.path.basename(read1_source)
		read2_filename = os.path.basename(read2_source)

		#replace 'fq' with 'fastq'
		for wrong in ['fq', 'FQ', 'FASTQ']:
			read1_filename = read1_filename.replace(wrong, 'fastq')
			read2_filename = read2_filename.replace(wrong, 'fastq')

		#add 'R1' and 'R2' to respective reads if not there; edit '_1.fastq' and '_2.fastq' to '_R1.fastq' and '_R2.fastq', specifically (most common issue)
		if read1_filename.find('_R1') == -1:
			if read1_filename.find('_1.fastq') != -1:
				read1_filename = read1_filename.replace('_1.fastq', '_R1.fastq')
			else:
				read1_filename = ('_R1.fastq').join(read1_filename.split('.fastq'))
		if read2_filename.find('_R2') == -1:
			if read2_filename.find('_2.fastq') != -1:
				read2_filename = read2_filename.replace('_2.fastq', '_R2.fastq')
			else:
				read2_filename = ('_R2.fastq').join(read2_filename.split('.fastq'))
		
		#designate destination and name for links
		read1_dest = scratchDir+"/"+mergeName+"/fastq/"+read1_filename
		read2_dest = scratchDir+"/"+mergeName+"/fastq/"+read2_filename

		#create links to fastqs
		os.symlink(read1_source, read1_dest)
		os.symlink(read2_source, read2_dest)

	#make juicer directory
	os.mkdir(scratchDir+"/"+mergeName+"/juicer")

	#link juicer software files
	os.symlink(juicerDir, scratchDir+"/"+mergeName+"/juicer/scripts")

#RUN SPLITTER
#go into temp directory
os.chdir(scratchDir)

#run splitter from within it ### UPDATE LATER
os.system('/proj/phanstiel_lab/software/launch_pipeline/scripts/juicer_splitter.sh ' + email + splitterOptions)
#os.system('/nas/longleaf/home/ksmetz/Code/Projects/launch_pipeline/scripts/juicer_splitter.sh ' + email + splitterOptions)

#overwrite the original samplesheet + merge files with the edited samplesheet + merged files
samples.to_csv(scratchDir + "/" + combinedName + "samplesheet.txt", sep="\t", index=False)
mergedSamples.to_csv(scratchDir + "/" + combinedName + "mergeTable.txt", sep="\t", index=False)
