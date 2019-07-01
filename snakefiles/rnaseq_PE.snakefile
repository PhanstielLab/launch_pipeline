#!/usr/bin/env python3

import pandas as pd
import os

##### Load config and sample sheets #####

configfile: "config.yaml"

samples = pd.read_table(config["samples"]).set_index("sample", drop=False)

##### Define rules #####

rule all:
	input:
		expand("trim/{sample}_val_1.fq.gz", sample=samples.index),
		expand("trim/{sample}_val_2.fq.gz", sample=samples.index)

rule trim_trimGalore_PE:
	input:
		#lambda wildcards: samples.loc[wildcards.sample]["Read1"]
		read1 = lambda wildcards: samples.loc[wildcards.sample]["Read1"],
		read2 = lambda wildcards: samples.loc[wildcards.sample]["Read2"]
	output:
		"trim/{sample}_val_1.fq.gz",
		"trim/{sample}_val_2.fq.gz"
	params:
		dir = "trim/"
	shell:
		'module load trim_galore/0.4.3; '
		'trim_galore --gzip -o {params.dir} --paired {input.read1} {input.read2}; '