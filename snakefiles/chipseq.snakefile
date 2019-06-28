#!/usr/bin/env python3

import pandas as pd
import os

##### Load config and sample sheets #####

configfile: "config.yaml"

samples = pd.read_table(config["samples"]).set_index("sample", drop=False)

##### Define rules #####

rule all:
	input:
		'counts.tsv'

rule trim_galore:
	input:
		lambda wildcards: samples.loc[wildcards.sample]["Read1"]
	output:
		"trim/{sample}_trimmed.fq.gz"
	params:
		dir = "trim/"
	shell:
		'module load trim_galore/0.4.3; '
		'trim_galore --gzip -o {params.dir} {input}'

rule align_bwa:
	input:
		"trim/{sample}_trimmed.fq.gz"
	output:
		temp("align/{sample}.sam")
	params:
		index = config['bwa_index']
	threads: 8
	shell:
		'module load bwa/0.7.17; '
		'bwa mem -t {threads} {params.index} {input} > {output}'

rule sort_samtools:
	input:
		"align/{sample}.sam"
	output:
		temp("sort/{sample}.bam")
	threads: 8
	shell:
		'module load samtools/1.8; '
		'samtools sort -@{threads} -o {output} {input}'

rule stats_samtools:
	input:
		"sort/{sample}.bam"
	output:
		expand("align/stats/{sample}.txt", sample=samples.index)
	threads: 8
	shell:
		'module load samtools/1.8; '
		'samtools flagstat -@{threads} {input} > {output}'

rule filter_picardtools:
	input:
		"sort/{sample}.bam"
	output:
		bam = "align/{sample}.bam",
		metrics = "align/metrics/{sample}.txt"
	threads: 8
	shell:
		'module load java/10.0.2; '
		'java -Xmx16g -jar /nas/longleaf/apps/picard/2.10.3/picard-2.10.3/picard.jar '
		'MarkDuplicates I={input} O={output.bam} M={output.metrics} '
		'REMOVE_SEQUENCING_DUPLICATES=true'

rule index_samtools:
	input:
		"align/{sample}.bam"
	output:
		"align/{sample}.bam.bai"
	threads: 8
	shell:
		'module load samtools/1.8; '
		'samtools index {input} {output}'

rule bedgraphs_unmerged:
	input:
		'align/{sample}.bam'
	output:
		'bedgraphs_unmerged/{sample}.bedgraph'
	threads: 8
	shell:
		'module load bedtools/2.26; '
		'bedtools genomecov -bga -ibam {input} > {output}'

rule macs2_unmerged:
	input:
		'align/{sample}.bam'
	output:
		file = 'peaks_unmerged/{sample}_peaks.narrowPeak'
	params:
		name = '{sample}'
	threads: 8
	shell:
		'module load macs/2016-02-15; '
		'macs2 callpeak -t {input} -f BAM -g hs -B --outdir peaks_unmerged -n {params.name}'

rule merge_peaks:
	input:
		expand("peaks_unmerged/{sample}_peaks.narrowPeak", sample=samples.index)
	output:
		'merged/peakMerge.narrowPeak'
	threads: 8
	shell:
		'module load bedtools/2.26; '
		'cat {input} | awk \'{{ OFS="\\t" }};{{ print $1, $2, $3, $4 }}\' | sort -k1,1 -k2,2n | bedtools merge > {output}'

rule count_bedtools:
	input:
		bam = expand("align/{sample}.bam", sample=samples.index),
		bai = expand("align/{sample}.bam.bai", sample=samples.index),
		bed = 'merged/peakMerge.narrowPeak',
	output:
		initial = temp('temp_counts.tsv'),
		final = 'counts.tsv'
	params:
		header = expand('{sample}', sample=samples.index)
	threads: 8
	shell:
		'module load bedtools/2.26; '
		'bedtools multicov -bams {input.bam} -bed {input.bed} > {output.initial}; '
		'awk -v OFS="\\t" \'BEGIN{{print "chr", "start", "end", "{params.header}" }}; {{print}}\' {output.initial} > {output.final}'