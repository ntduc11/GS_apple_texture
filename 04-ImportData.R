cat("Importing data...\n")

# Loading and formatting phenotypic and genotypic data
# Last sanity check and cleaning are included

##########################################################
###################### PHENOTYPES ########################
##########################################################

## Repeated measures of texture (5 biological and 4 technical replicates per genotype)
phenos<-read.table(paste0(idir, "/rep_meas_TEXTURE_4R.txt"), h=T, sep="\t") ## this for analyses
phenos$Year<-as.factor(phenos$Year)
levels(phenos$Name) %>% length
Names<-sort(levels(phenos$Name))

traits=colnames(phenos)[-c(1:6)]
cat("traits:")
par(mfrow=c(3,4))
lapply(traits, function(i) print(hist(phenos[[i]], main="", xlab=i)))

## calculate means per apple - we are not interested in technical variability
phenos_techrep=phenos ## keep repeated data
phenos<-aggregate(cbind(sapply(traits, function(x) phenos[,x]))~ Year + Name + Apple + Location, data=phenos, mean)


##########################################################
###################### GENOTYPES #########################
##########################################################

genos_ready<-fread(paste0(idir, "/SNPs_additive_coding_04092019.txt"))[,-1] %>% as.matrix
rownames(genos_ready)<-read.table(paste0(idir, "/rownames_SNPs_additive_coding_FuPi_cor.txt"), sep="\t", h=T)[,"name"] %>% as.character

## parents

parents<- read.table(paste0(idir, "/families_parents.txt"), sep="\t", h=T)

## remove identified outcrossers from both datasets
## all appart from GDFj_024 and FuPi_089 in outcrosser file
outcrossers<-c("FuPi_089", "FjPi_089",
               lapply(c("001","023","048","049","006","007","029","040","050"), function(x) paste0("GaPL_",x ))%>%unlist,
               lapply(c("028","060"), function(x) paste0("FjPL_",x ))%>%unlist,
               lapply(c("024","042","048", "050", "051", "058", "087"), function(x) paste0("GDFj_",x ))%>%unlist,
               lapply(c("065","066", "067", "068", "069", "070","071", "073", "075", "076", "077", "080"), function(x) paste0("FjDe_",x ))%>%unlist)

lapply(outcrossers, function(x) grep(x,rownames(genos_ready))) %>% unlist
to_remove<-lapply(outcrossers, function(x) grep(x,rownames(genos_ready))) %>% unlist
genos_ready<-genos_ready[-to_remove,]
phenos<-phenos[-which(phenos$Name %in% outcrossers),]
## found some spaces in rownames of genos_ready
grep(" ",rownames(genos_ready))
rownames(genos_ready)[573]<-"Limonc"
rownames(genos_ready)[66]<-"Coop30"

## identify spaces in names
grep(" ", rownames(genos_ready))
phenos$Name[grep(" ", phenos$Name)] ### Gala bukeye will be removed no problem

## Identify clones in genos
## this is taking time you can directly use the file saved
# identical<-list()
# 
# for (i in c(1:(nrow(genos_ready)-1))) {
#   for (j in (i+1):nrow(genos_ready)) {
#     # print(i)
#     # print(j)
#     if((summary(genos_ready[i,] == genos_ready[j,])["TRUE"]==ncol(genos_ready))){
#       identical<-append(identical, list(c(i,j)))
#     } else {
#       next
#     }
#   }
# }
# 
# lapply(identical, function(x)c(rownames(genos_ready)[x[[1]]], rownames(genos_ready)[x[[2]]]))
# saveRDS(identical, file=paste0(odir, "/genos_modelled/clones_identified_in_geno_ready.rds"))

## need to merge clones at phenotypic levels and to remove them in genotype file
identical=readRDS(file=paste0(odir, "/genos_modelled/clones_identified_in_geno_ready.rds"))
to_remove=lapply(identical, function(x) x[[1]]) %>% unlist
to_replace<-list(lapply(identical, function(x) rownames(genos_ready)[x[[1]]]) %>% unlist, lapply(identical, function(x) rownames(genos_ready)[x[[2]]]) %>% unlist)
genos_ready<-genos_ready[-c(to_remove),]

## replace phenos names for clones
phenos_test=phenos
lapply(1:length(to_replace [[1]]), function(x) {
  print(to_replace [[2]][[x]])
  which(phenos_test$Name == to_replace [[2]][[x]])})
## update to  replace: only two changes to make
to_replace[[1]]<-c("BadGol","GaPi_039")
to_replace[[2]]<-c("GolDel","GaPi_040")
phenos_test$Name<-as.character(phenos_test$Name)
mapply(function(x,y) phenos_test[which(phenos_test$Name == x), "Name"] <<- y , to_replace[[1]], to_replace[[2]] ) ## do not forget symbol << recursive to make an actual change!
## sanity checks
lapply(to_replace[[1]], function(x) grep(x, phenos$Name) %>% length)
lapply(to_replace[[1]], function(x) grep(x, phenos_test$Name) %>% length)
lapply(to_replace[[2]], function(x) grep(x, phenos$Name) %>% length)
lapply(to_replace[[2]], function(x) grep(x, phenos_test$Name) %>% length)
## replace original pheno file
phenos<-phenos_test
phenos$Name<-as.factor(phenos$Name)

##################################################################
############## OVERLAP PHENOS/GENOS ##############################
##################################################################

## keep only what has been phenotyped/genotyped reciprocally
## some checks
phenos$Name[which(!(phenos$Name %in% rownames(genos_ready)))] %>% as.character %>% unique
phenos$Name[which(!(levels(phenos$Name) %in% rownames(genos_ready)))] %>% as.character %>% unique %>% length
phenos$Name[which((phenos$Name %in% rownames(genos_ready)))] %>% as.character %>% unique%>% length
## phenos update
phenos<-phenos[which(phenos$Name %in% rownames(genos_ready)),]
phenos<-droplevels(phenos)
phenos$Trial<-paste0(phenos$Location, phenos$Year)
## genos update
genos_ready<-genos_ready[which(rownames(genos_ready) %in% levels(phenos$Name)),]

###########################################
######### GENOTYPE DATA FILTERING #########
###########################################
## Data already filter MAF >0.05 and call rate > 0.5 for individuals but in larger population
## repeat filtering on subset of individuals (pheno + geno)
genos_fil<-apply(genos_ready,2, function(x) as.numeric(x) %>% round(., digits=0))
## reshape for snpStats - recode 0,1,2 and NA are 9
genos_fil[which(is.na(genos_fil))]<-8
rownames(genos_fil)<-rownames(genos_ready)
genos_fil<- genos_fil + 1
genos_fil[genos_fil==3]=2
genos_fil<-new("SnpMatrix", as.matrix(genos_fil) )
## filter data
idsum<-row.summary(genos_fil)
snpsum<-col.summary(genos_fil)
## filter for these values of Z
snpsel=snpsum[which(snpsum$Call.rate>0.20 & snpsum$MAF>0.05 ),] ## do not filter on HWE
nrow(snpsum)-nrow(snpsel)## filtering out 1941 Mks
idsum<-row.summary(genos_fil)
## filter genos_ready
genos_ready<-genos_ready[,rownames(snpsel)]
dim(genos_ready)
## impute
genos_ready<-impute.knn(t(genos_ready)) ## very few to impute due to duplicates
genos_ready<-t(genos_ready$data)

#############################
######### SAVE DATA #########
#############################

# Here turned off for simplicity, as we may use directly the data in the subsequent scripts
# saveRDS(phenos, file=paste0(idir, "/phenos_ready_for_pred.rds"))
# saveRDS(genos_ready,file=paste0(idir, "/genos_imputed_for_pred.rds"))
# saveRDS(phenos_techrep,file=paste0(idir, "/phenos_with_reps_raw_filtered.rds"))

######################################
######### reate useful lists #########
######################################

families<-c("FjDe", "GDFj", "FjPi", "FjPL", "GaPi", "GaPL")
lapply(families, function(x) grep(x, rownames(genos_ready)[rownames(genos_ready) %in% phenos$Name]) %>% length)
lapply(families, function(x) grep(x, rownames(genos_ready)[rownames(genos_ready) %in% phenos$Name])) %>% unlist %>% length
WhichFAM<-lapply(families, function(x) grep(x, rownames(genos_ready)[rownames(genos_ready) %in% phenos$Name])) %>% unlist
WhichCOL<-rownames(genos_ready)[-WhichFAM] 
## last check: verify the absence of spaces in rownames
grep(" ", WhichCOL)
grep(" ", rownames(phenos))
length(WhichCOL)
# lapply(families, function(x) grep(x, rownames(genos_ready)[rownames(genos_ready) %in% phenos$Name])) %>% unlist %>% length
cat("Families:")
print(families)
ids<-rownames(genos_ready)
NbInd<- length(ids)

# Purge obsolete variables

rm(phenos_test)

cat("Data imported!\n")

