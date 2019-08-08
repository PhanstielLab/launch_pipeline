# NAMER 
#    Generates a project name based on the samples run by listing common column fields (1) and concatonating others (2)
def namer(configPD, columnNamesSingle, columnNamesCombine, replicateColumns, joiner=""):

    nameList = []

    # For columns which you want to list ONLY if there is a single one
    for column in columnNamesSingle:
        columnSet = set(configPD[column])      
        if len(columnSet) == 1:
        	for i in columnSet:
	            nameList.append(str(i))
        else:
            nameList.append("CMB")

    # For columns which you want to squish together all used
    for column in columnNamesCombine:
        columnSet = set(configPD[column])
        nameList.append(joiner.join(str(i) for i in columnSet))

    # For replicate columns (Bio, Tech, Seq)
    repList = []
    for column in replicateColumns:
        columnSet = set(configPD[column])
        if len(columnSet) > 1:
            repList.append("0")
        elif len(columnSet) == 1:
            repList.append(str(list(columnSet)[0]))
    nameList.append(".".join(repList))

    return("_".join(nameList))