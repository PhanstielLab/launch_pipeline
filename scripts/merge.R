
### INPUT #################

# # For command line use (untested!)
# args <- commandArgs(trailingOnly=T)
# sampleSheet = read.table(args[1], sep="\t", header=T, colClasses="character")
# mergeBy     = list(args[2])

# Test data
sampleSheet = data.frame(names=paste0("s", 1:8), 
                 cell=rep("CHND", times=8), 
                 cond=c(rep("NAN", times=5), rep("OAR", times=3)), 
                 time=c(rep("OLD", times=3), rep("YNG", times=2), rep("NAN",times=3)), 
                 br=c(1,2,2,1,2,1,2,2), 
                 tr=c(1,1,2,1,1,1,1,2), 
                 sr=rep(1 ,times=8), 
                 misc=c("note", rep("", times=5), "other", "note"),
                 mergeName=c('A', 'B', 'A', 'A', 'A', 'A', 'A', 'B'))
sampleSheet = read.delim('~/Dropbox/Work/Research/Data/Projects/NIAP/NIAPconfig.txt')
sampleSheet = read.table('~/Desktop/config_LIMA_THP1_WT_LPIF_S_190214_011008.tsv', sep="\t", header=T, colClasses="character")

# What you're merging together...
mergeBy = c("Project", "Cell_Type", "Genotype", "Condition", "Time", "Tag")



### CODE #################
# Create a new column that's every unique combination of your mergeBy variables (names of the final merged files)
sampleSheet$mergeName = apply(as.data.frame(sampleSheet[,mergeBy]), 1, paste, collapse="_")

# # Testing!
# for (var in unique(sampleSheet$mergeName)){
#   print(mergeSheet[sampleSheet$mergeName == var,])
# }

# For each final merged file, grab the names of the samples that fit into that merge
mergeSamples <- lapply(unique(sampleSheet$mergeName), function(var){
  sampleSheet[,"Name"][sampleSheet$mergeName == var]
})
names(mergeSamples) = unique(sampleSheet$mergeName)

# Make sure that all the sample lists are the same size (extend with NA's)
mergeSamples = lapply(mergeSamples, `length<-`, max(sapply(mergeSamples, length)))



### OUTPUT #################
# Print the transformed matrix to a csv to be read into the launch script
t(as.data.frame(mergeSamples))
#write.csv(t(as.data.frame(mergeSamples)))


