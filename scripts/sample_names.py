import pandas as pd
import argparse

parser = argparse.ArgumentParser(description="Put in path to samplesheet.")
parser.add_argument("--samplesheet", action = "store", type = str, dest="samplesheet", help = "samplesheet path.", required = True)
args = parser.parse_args()
samplesheet = args.samplesheet

samples = pd.read_csv(samplesheet, sep='\t')
sample_names = []

for ind in samples.index:
	samplename = samples["sample"][ind]
	sample_names.append(samplename)

print(sample_names)