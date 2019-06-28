## Load packages
library(data.table)

## Function to split and merge a data table
## dat is the sample data
## mergeby is the name of the column to merge samples by
## same is the name of the column(s) that should be the same between merged samples
mergeList <- function(dat, mergeby, same){
  ## Subset data by levels of mergeby (splitting variable)
  mergebyLevels <- lapply(levels(as.factor(dat[[mergeby]])), function(x) subset(dat, eval(as.name(mergeby)) == x))
  
  ## Merge data by the columns that should remain the same
  Reduce(function(...) merge(..., by=same, allow.cartesian=T), mergebyLevels)
}


## Load data
dat <- fread("etc/samples.txt")
mergeby <- "Bio_Rep"

mergeList(dat, "Bio_Rep", c("Target"))

dat <- fread("etc/test.txt")
mergeby <- "rep"

mergeList(dat, "rep", c("time", "condition", "cell"))
