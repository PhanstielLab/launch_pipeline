import pandas as pd
import os
import argparse
import getpass
from namer import namer
import tempfile as temp


#INPUTS
#command line inputs
parser = argparse.ArgumentParser(description="Put in path to juicer directories.")
parser.add_argument("--tempDirectory", action = "store", type = str, dest = "scratchDir", help = "Path to temp directory in scratch space.", default = None, required = False)
parser.add_argument("--juicerOptions", action = "store", type = str, dest = "juicerOptions", help = "Additional options to pass to juicer command.", default = "", required = False)

args = parser.parse_args()

#assign inputs to variables
juicerOptions = args.juicerOptions
scratchDir = args.scratchDir

# Set default scratchDir to pwd
if scratchDir is None:
	scratchDir = os.getcwd()

samplesheetcounter=0
mergetablecounter=0
for file in os.listdir(scratchDir):
	if file.endswith("samplesheet.txt"):
		samplesheetcounter=samplesheetcounter+1
		samplesheet=file
	if file.endswith("mergeTable.txt"):
		mergetablecounter=mergetablecounter+1
		mergetable=file

if samplesheetcounter < 1:
	raise ValueError('No samplesheet found in directory. Please make sure "launch juicer prep" has been run.')
if mergetablecounter < 1:
	raise ValueError('No merge table found in directory. Please make sure "launch juicer prep" has been run.')

if samplesheetcounter > 1:
	raise ValueError('Multiple samplesheets found in this directory. Please delete some.')
if mergetablecounter > 1:
	raise ValueError('Multiple merge tables found in this directory. Please delete some.')

#find samplesheet, mergeTable
samplesheet_path = os.path.realpath(samplesheet)
mergetable_path = os.path.realpath(mergetable)

#convert samplesheet.txt, mergeTable.txt into pandas dataframe
samples = pd.read_csv(samplesheet_path,  sep='\t', nrows=1) # Just take the first row to extract the columns' names
col_str_dic = {column:str for column in list(samples)} 		# Make sure you're reading everything as a string!!!
samples = pd.read_csv(samplesheet_path, sep='\t', dtype=col_str_dic)

mergedSamples = pd.read_csv(mergetable_path,  sep='\t', nrows=1) # Just take the first row to extract the columns' names
col_str_dic = {column:str for column in list(mergedSamples)} 		# Make sure you're reading everything as a string!!!
mergedSamples = pd.read_csv(mergetable_path, sep='\t', dtype=col_str_dic)

# Make sure required columns are present
if 'JuicerOutputDir' not in samples.columns: 
	raise ValueError("Samplesheet does not have required 'JuicerOutputDir' column. This column must exist in order to properly move the files after running.") 

# Print the merged dataframe
os.system("cat " + mergetable_path)

#RUN JUICER
#for each merge group, build it's own juicer directory, put fastqs from all samples into it, and launch juicer
for mergeGroupIdx in mergedSamples.index:

	mergeName = mergedSamples.loc[mergeGroupIdx, "MergeName"]
	outputDir = mergedSamples.loc[mergeGroupIdx, "JuicerOutputDir"]
	
	#RUN JUICER
	#go into sample directory
	os.chdir(scratchDir+"/"+mergeName)

	#run juicer from within it
	os.system('./juicer/scripts/juicer.sh -P ' + outputDir + ' ' + juicerOptions)

	#go back to scratchspace
	os.chdir(scratchDir)
