#!/bin/bash

## Make fastq directory
mkdir fastq

## Create fastq links
for i in $(cat "${1}"); do ln -s "${i}" fastq/; done

## Make juicer directory to prevent accidential deletion of scripts
mkdir juicer

## Link juicer files
ln -s /proj/phanstiel_lab/software/juicer/juicer/SLURM/scripts/ juicer/scripts

# Run juicer
./juicer/scripts/juicer.sh