#!/usr/bin/env python3

import pandas as pd
import os

##### Load config and sample sheets #####

configfile: "config.yaml"

samples = pd.read_table(config["samples"], header = None).set_index(0, drop=False)

## Get basenames
basenames = samples[0].apply(lambda x: os.path.splitext(os.path.basename(x))[0])

## Set index to correspond with basenames
samples = samples.set_index(basenames, drop=False)

##### Define rules #####

rule all:
	input:
		expand('subsampled/sub_{sample}.fastq.gz', sample=samples.index)

rule subsample:
	input:
		lambda wildcards: samples.loc[wildcards.sample][0]
	output:
		'subsampled/sub_{sample}.fastq'
	params:
		reads = config['subsample_reads']
	shell:
		'module load seqtk; '
		'seqtk sample -s100 {input} {params.reads} > {output}'

rule gzip:
	input:
		'subsampled/sub_{sample}.fastq'
	output:
		'subsampled/sub_{sample}.fastq.gz'
	shell:
		'gzip {input}'