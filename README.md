# launch_pipeline
***********************

### Overview
***********************
launch_pipeline is an integrated wrapper for launching all Phanstiel lab pipelines.

The majority of the pipelines are written using the Snakemake framework, and launched with the executable launch script. This pipeline is intended to be run on the UNC HPC longleaf cluster with SLURM. For compatibility with other systems, adjust the fixed paths in the configuration files and adjust the cluster parameters as necessary.

#### Setup (for Phanstiel Lab users)
**********************
To setup the pipeline launcher, run the following commands:

```{bash eval=F}
ln -s /proj/phanstiel_lab/software/launch_pipeline/etc/bash_completion $HOME/.config/bash_completion

printf "# Load phanstiel modulefiles\nmodule use /proj/phanstiel_lab/modulefiles\n" >> $HOME/.bashrc
```

These commands will add the bash completion functionality to the launch command and make Phanstiel lab-specific module files available for use. For these features to work, first `exit` from the terminal session and restart.

### Quick Start
**********************
1. Load module:
```{bash eval=F}
module load launch_pipeline
```
2. Launch Pipeline:
```{bash eval=F}
launch <pipeline> <samplesheet.txt> [options]
```

Tab-complete for available pipelines. Use `-h` or `--help` for more usage information.
