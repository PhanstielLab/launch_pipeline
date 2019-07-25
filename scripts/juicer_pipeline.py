import pandas as pd
import os
import argparse
import getpass



#juicerDir="/proj/phanstiel_lab/software/juicer/juicer/SLURM/scripts/"
juicerDir="/pine/scr/n/e/nekramer/test_juicer/juicer/juicer/SLURM/scripts/"

#allow for input of samplesheet
parser = argparse.ArgumentParser(description="Put in samplesheet.")
parser.add_argument("--samplesheet", action = "store", type = str, dest="samplesheet", help = "samplesheet.", required = True)
args = parser.parse_args()
samplesheet = args.samplesheet
samplsheet_path = os.path.realpath(samplesheet)

#get username information to put jobs in scr space
username = getpass.getuser()
scrspace = "/pine/scr/"+username[0]+"/"+username[1]+"/"+username

#convert samplesheet.txt into pandas dataframe
samples = pd.read_csv(samplesheet_path, sep='\t')

#go through each sample
for ind in samples.index:

	#get samplename from sample sheet
	samplename = samples["sample"][ind]
	
	#make it it's own directory
	
	os.mkdir(scrspace+"/"+samplename)

	#within that directory, make it's own fastq directory
	os.mkdir(scrspace+"/"+samplename+"/fastq")

	#get paths to reads for fastqs
	read1_source = samples["Read1"][ind]
	read2_source = samples["Read2"][ind]
	
	#designate destination and name for links
	read1_dest = scrspace+"/"+samplename+"/fastq/"+os.path.basename(read1_source)
	read2_dest = scrspace+"/"+samplename+"/fastq/"+os.path.basename(read2_source)

	#create links to fastqs
	os.symlink(read1_source, read1_dest)
	os.symlink(read2_source, read2_dest)

	#make juicer directory
	os.mkdir(scrspace+"/"+samplename+"/juicer")

	#link juicer software files
	os.symlink(juicerDir, scrspace+"/"+samplename+"/juicer/scripts")

	#RUN JUICER
	#go into sample directory
	os.chdir(scrspace+"/"+samplename)
	#run juicer from within it

	os.system("./juicer/scripts/juicer.sh "+samplesheet_path)


	#go back to scratchspace
	os.chdir(scrspace)





