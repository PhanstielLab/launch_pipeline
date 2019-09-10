#!/usr/bin/env Rscript

## Function to create a merge list from a sample sheet ####
createMergeList <- function(sampleSheet, mergeBy){
  ## Read in sampleSheet
  sampleSheet <- read.table(file = sampleSheet, sep="\t", header=T, colClasses="character", fill=TRUE)
  
  ## Check to make sure all columns are in the sampleSheet
  if(!all(mergeBy %in% colnames(sampleSheet))) stop("Column names must be in the sample sheet.")
  
  ## Create merge names from columns specified in mergeBy and add them to sampleSheet
  sampleSheet$mergeName <- apply(as.data.frame(sampleSheet[,mergeBy]), 1, paste, collapse="_")
  
  ## Subset sampleSheet by each mergeName; return a list of sample names belonging to each merge name
  mergeSamples <- lapply(unique(sampleSheet$mergeName), function(var){
    sampleSheet[,"sample"][sampleSheet$mergeName == var]
    # sampleSheet[sampleSheet$mergeName == var,] # for testing
  })
  names(mergeSamples) <- unique(sampleSheet$mergeName)
  
  ## Make sure that all the sample lists are the same size (extend with NA's)
  mergeSamples <- lapply(mergeSamples, `length<-`, max(sapply(mergeSamples, length)))
  
  ## Create a data frame of sample names that belong to each mergeName
  mergeList <- t(as.data.frame(mergeSamples))
  mergeList <- cbind(rownames(mergeList), mergeList)
  colnames(mergeList) <- c("MergeName", paste0("Sample_", 1:(ncol(mergeList)-1)))
  
  return(mergeList)
}

## Prints columns to fit the terminal window
options(width=system("tput cols", intern=TRUE))

## Parse command line input
args <- commandArgs(trailingOnly = T)
sampleSheet <- args[1]
output <- args[2]
mergeBy <- args[-c(1, 2)]

## Check that the sampleSheet is a valid file
if(!file.exists(sampleSheet)) stop(paste0(sampleSheet, " file does not exist"))

## Create mergeList; print result to the console; write results to "mergeList.txt"
mergeList <- createMergeList(sampleSheet, mergeBy); print(mergeList, quote = F)
write.table(mergeList, file = output, sep = "\t", quote = F, row.names = F)
