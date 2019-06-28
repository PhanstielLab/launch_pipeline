#!/usr/bin/env python3

import pandas as pd
import os

##### Load config and sample sheets #####

configfile: "config.yaml"

samples = pd.read_table(config["samples"]).set_index("sample", drop=False)

##### Define rules #####

rule all:
	input:
		'counts.txt'

include: os.path.join(config['rule_path'], "trim.rule")
include: os.path.join(config['rule_path'], "align.rule")
include: os.path.join(config['rule_path'], "sort.rule")
include: os.path.join(config['rule_path'], "index.rule")
include: os.path.join(config['rule_path'], "count.rule")