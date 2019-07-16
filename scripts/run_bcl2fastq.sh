#!/bin/bash

## Load module
module load bcl2fastq2

## Submit SLURM job
sbatch <<-CONVERT
	#!/bin/bash
	#SBATCH -J bcl2fastq
	#SBATCH -N 1
	#SBATCH -n 1
	#SBATCH -t 1440
	#SBATCH --mem=16g
	#SBATCH -o bcl2fastq.log.out
	#SBATCH -e bcl2fastq.log.err

	mkdir fastq
	bcl2fastq -o fastq/

	mkdir meta
	mv * meta/
	mv meta/fastq .

	mv fastq/Reports meta/Reports
	mv fastq/Stats meta/Stats

CONVERT


