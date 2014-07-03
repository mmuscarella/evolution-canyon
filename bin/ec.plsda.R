################################################################################
#                                                                              #
#	Evolution Canyon Project: Microbial Community PL-SDA                       #
#                                                                              #
################################################################################
#                                                                              #
#	Written by: Jay Lennon and Mario Muscarella                                #
#                                                                              #
#	Last update: 2014/06/24                                                    #
#                                                                              #
################################################################################

#### Things left to do	
	# use greenegenes or silva database --> done?
	# confirm factors are set up right (paired) --> not sure
	# confirm normalization (relative recovery, log transformation) --> prob OK
	# figure out how to get explained total variance for each axis --> done
	# figure out how to identify influential taxa using loadings --> not yet
	# load taxonomy in (see Pmeso code on github) --> getting there
	# consider removal of rare taxa --> not yet
	# use Stuart's PERMANOVA that accounts for paired samples --> new file?
	# confirm these are actually "bad": EC-2A-D, EC-2A-R, EC-2C-R, EC-2D-R

ec.pcoa <- function(shared = " ", design = " ", plot.title = "test"){

  source("./bin/DiversityFunctions.r")  
  require(vegan)                                   
  require(mixOmics)
  require(som)
  
#1 -- Import data (site by OTU matrix) and deal w/ "problem" samples
  ec_data <- t(read.otu(shared, "0.03")) # takes a long time (10 mins)
  design <- read.delim(design, header=T, row.names=1) 
  # make sure design command in EC.test.r is run first 
 
  # Note: owing to amplification issues, we only submitted 76 of 80 samples. 
  # The four samples NOT submitted were C-1E-R, EC-2G-R, EC-2J-R, EC-6I-D
  # So, removed their pairs for PLS-DA: EC-1E-D, EC-2G-D, EC-2J-D,EC-6I-R
  # 4 samples have had crappy quality in past: EC-2A-D, EC-2A-R, EC-2C-R, EC-2D-R
  # Automatically exlcuded, but may want to look again
  # Remove their pairs EC-2C-D, EC-2D-R
  # Results in a total of 66 samples (14 problematics)
  # Use following code to identify columns to remove
  
  samps <- (colnames(ec_data))
  which(samps == "EC-2A-D")
  
  ec_data_red <- ec_data[,-c(9,20:21,24:27,32,37,74)] 
  # removes problematic samples and their pairs
  
  samps_red <- colnames(ec_data_red) # recover samples from reduced dataset
  design_red <- design[samps_red,] # design matrix w/o problem samples & pairs
  design_red$paired <- c(rep(seq(1:14), each=2), rep(seq(1:19), each=2)) 
  # design matrix with renumbered pairs after removing problem pairs
  
#2 -- Options for transformation, relativation, and normalization
  Xt <- t(ec_data_red) # transpose sample x OTU matrix; necssary for 'multilelvel'
  Xlogt <- decostand(Xt,method="log")
  Xpa <- (Xt > 0)*1 # Calculate Presense Absence
  Xrel <- ec_data_red
  	for(i in 1:ncol(ec_data_red)){
    Xrel[,i] = ec_data_red[,i]/sum(ec_data_red[,i])}  
  Xrelt <- t(Xrel)
  Xlog <- decostand(ec_data_red,method="log")
  Xrellog <- Xlog
  	for(i in 1:ncol(Xlog)){
    Xrellog[,i] = Xlog[,i]/sum(Xlog[,i])}  
  Xrellogt<-t(Xrellog)
  X <- normalize(Xrelt,byrow=TRUE) # normalizing by row (mean = 0, var = 1) with som package, not mixOmics
  
  # Some comments on normalization: In mixOmics "default is PLS centers data by substracting mean of each column 
  # (variables) and scaling with the stdev. Result is that each column has a mean zero and a variance of 1
  # personal communication with Kim-Anh Le Cao (mixOmics developer). However, it appears that 'multilevel' 
  # procedure doesn't run w/o normalization



#3a

# one way design following mixomics example
# new design with slope.molecule as one column (e.g., AFDNA) and station (e.g, 1,2,5,6)
# multilevel (X,cond=ec_desigh$slope.mol, sample=ec_design$station)
  slope <- design_red$slope # factor 1
  molecule <- design_red$molecule # factor 2 
  site <- design_red$site
  station <- design_red$station
  slope.molecule <- data.frame(cbind(as.character(slope),as.character(molecule))) # Y matrix with factor 1 and 2
  slope.molecule.concat <- do.call(paste, c(slope.molecule[c("X1", "X2")], sep = "")) # create unique treat ID vector
  pair.station <- c(1,1,2,2,3,3,4,4,5,5,6,6,7,7,8,8,9,9,1,1,2,2,3,3,4,4,5,5,1,1,2,2,3,3,4,4,5,5,6,6,7,7,8,8,9,9,10,10,1,1,2,2,3,3,4,4,5,5,6,6,7,7,8,8,9,9)
  station.molecule.concat <- paste(station, molecule, sep = "")

one.way <- multilevel(X, cond = slope.molecule.concat, sample = pair.station, ncomp = 3, method = 'splsda') 

EC_multilevel <- one.way

# Skip to #6


two.way <- multilevel(X, cond = slope.molecule, sample = pair.station, ncomp = 3, method = 'splsda') 

EC_multilevel <- two.way


Xlogt <- decostand(Xt,method="log")[,which(colSums(Xlogt) !=0)]

two.way <- multilevel(Xlogt, cond = slope.molecule, sample = pair.station, ncomp = 2, method = 'splsda') 

EC_multilevel <- two.way


#3 -- MULTILEVEL ANALYSIS
  slope <- design_red$slope # factor 1
  molecule <- design_red$molecule # factor 2 
  site <- design_red$site
  slope.molecule <- data.frame(cbind(as.character(slope),as.character(molecule))) # Y matrix with factor 1 and 2
  slope.site <- data.frame(cbind(as.character(slope), as.character(site)))
  slope.molecule.concat <- do.call(paste, c(slope.molecule[c("X1", "X2")], sep = "")) # create unique treat ID vector
  slope.site.concat <- do.call(paste, c(slope.site[c("X1", "X2")], sep = ""))
  paired <- design_red$paired # identifies paired samples (i.e., DNA-RNA)
  EC_multilevel <- multilevel(X, cond = slope.molecule, sample = paired, ncomp = 3, method = 'splsda') 
  # change up "X" in multilevel to reflect transformation, etc. above 
  
#4 -- Variation Explained by axis
  # Calculate distance between samples (Bray Curtis or Euclidean?)
  X.dist  <- vegdist(X,method="euclidean") 
  # Shouldn't "ec_data_red be "X"?; however, crashes R!
  # This might explain why var 3> var; doesn't match with multilevel output
  # Calculate distance between samples in reduced (ordination) space
  plsda.1 <- dist(EC_multilevel$variates$X[,1],method="euclidean")
  plsda.2 <- dist(EC_multilevel$variates$X[,2],method="euclidean")
  plsda.3 <- dist(EC_multilevel$variates$X[,3],method="euclidean")
  # Calculate variation explained
  var1 <- cor(X.dist, plsda.1)
  var2 <- cor(X.dist, plsda.2)
  var3 <- cor(X.dist, plsda.3)

#5 -- Contribution (%) variance of factors (Y) to PLS-DA axes
  # mostly lifed from http://perso.math.univ-toulouse.fr/mixomics/faq/numerical-outputs/
  # not sure what "Rd" means. U are the "variates"...
  Y <- slope # maybe this should be done one-at-a-time (e.g., slope and molecule)
  Rd.YvsU = cor(as.numeric(as.factor(Y)),EC_multilevel$variates$X) # turns categorical vars into quantitative
  Rd.YvsU = apply(Rd.YvsU^2, 2, sum)
  Rd.Y = cbind(Rd.YvsU, cumsum(Rd.YvsU))
  colnames(Rd.Y) = c("Proportion", "Cumulative")
  Rd.Y # percent of variance explained by each component
   
#6 -- PLOTTING 
  points <- EC_multilevel$variates$X 
  par(mar=c(5,5,1,1), oma=c(1,1,1,1)+0.1 ) # plot margins, outer margin area
  plot(points[,1], points[,2], xlab="PLSDA Axis 1 ", ylab="PLSDA Axis 2", 
  xlim=c(min(points[,1])+min(points[,1])*0.1,max(points[,1])+max(points[,1])*0.1),
  ylim=c(min(points[,2])+min(points[,2])*0.1,max(points[,2])+max(points[,2])*0.1),
  pch=16, cex=2.0, type="n",xaxt="n", yaxt="n", cex.lab=1.5, cex.axis=1.2) 
  axis(side=1, las=1) # add x-axis ticks and labels  
  axis(side=2, las=1) # add y-axis ticks and labels   
  abline(h=0, lty="dotted") # add horizontal dashed line at 0 
  abline(v=0, lty="dotted") # add vertical dashed line at 0 
  mol.shape <- rep(NA, dim(points)[1])
    for (i in 1:length(mol.shape)){
      if (molecule[i] == "DNA"){mol.shape[i] = 21}
      else {mol.shape[i] = 22}
      } # identifies symbol shape based on molecule
  slope.color <- rep(NA, dim(points)[1])
    for (i in 1:length(slope.color)){
      if (slope[i] == levels(slope)[1]) {slope.color[i] = "brown"}
      else {slope.color[i] = "green3"}
      } # identifies symbol color based on slope; error here? slope insted of slope.color?
  points(points[,1], points[,2], pch=mol.shape, cex=2.0, col="black", bg=slope.color, lwd=2)
  #text(points[,1], points[,2], row.names(points))   
  ordiellipse(cbind(points[,1], points[,2]), slope.molecule.concat, kind="sd", conf=0.95,
    lwd=2, lty=2, draw = "lines", col = "black", label=TRUE)
  #ordiellipse(cbind(points[,1], points[,2]), station.molecule.concat, kind="sd", conf=0.95,
  #  lwd=2, lty=2, draw = "lines", col = "black", label=TRUE)  
   
#7 -- Other stuff: some note and tries based on following website:
  # http://perso.math.univ-toulouse.fr/mixomics/methods/spls-da/   
  # calculate the coefficients of the linear combinations
  pred <- predict(EC_multilevel, X[1:2, ])
  pred$B.hat
  # calculate R2 and Q2 values for sPLS-DA?
  # Q2 = "Q2 is the square of the correlation between the actual and predicted response"
  # warning = this is memory intenstive, but didn't crash
  val <- valid(EC_multilevel, criterion = c("R2", "Q2"))
  
  

  
 ### Stuff below is leftover from PCoA. May want to consider 
 
 # From P-Meso Project
 # Combine with Taxonomy
hetero.tax.raw <- (read.delim("../mothur/output/tanks.bac.final.0.03.taxonomy"))
hetero.tax <- transform(hetero.tax.raw, Taxonomy=colsplit(hetero.tax.raw[,3],
 split="\\;", names=c("Domain","Phylum","Class","Order","Family","Genus")))
rownames(hetero.tax) <- hetero.tax[,1]
rownames(heteros.bio) <- gsub("Otu0", "Otu", rownames(heteros.bio)) 
hetero.data <- merge(heteros.bio, hetero.tax, by = "row.names", all.x=T )
hetero.data <- hetero.data[order(hetero.data$group, -hetero.data$indval), ]
hetero.data <- hetero.data[hetero.data$Taxonomy$Phylum != "unclassified(100)",]


  
  
  # Remove OTUs that are rare across the data set
  total_seqs <-sum(colSums(ec_data_red))
  rare_OTUs <-total_seqs*0.0001 # "0.001" = 0.001%
  ec_data_red_rare <-ec_data_red[rowSums(ec_data_red) > rare_OTUs,]

  # Create Distance Matrix with bray (deafault), manhattan, euclidean, canberra, bray, kulczynski, jaccard, gower, altGower, morisita, horn, mountford, raup,    binomial, or chao. Most should be part of vegan, but possilbly 'labdsv' or 'BiodiversityR' packages
  samplePA.dist <- vegdist(t(dataPA),method="bray")
  #sampleREL.dist <- vegdist(t(dataREL),method="altGower")
  sampleREL.dist<- vegdist(decostand(t(dataREL),method="log"),method="altGower")
      
  # Principal Coordinates Analysis
  ec_pcoa <- cmdscale(sampleREL.dist,k=3,eig=TRUE,add=FALSE) 
    # Classical (Metric) Multidimensional Scaling; returns PCoA coordinates
    # eig=TRUE returns eigenvalues; k = # of dimensions to calculate

  # Percent Variance Explained Using PCoA (Axis 1,2,3)
  explainvar1 <- round(ec_pcoa$eig[1]/sum(ec_pcoa$eig)*100,2) 
  explainvar2 <- round(ec_pcoa$eig[2]/sum(ec_pcoa$eig)*100,2)
  explainvar3 <- round(ec_pcoa$eig[3]/sum(ec_pcoa$eig)*100,2)
  
  pcoap <- merge(as.data.frame(ec_pcoa$points),design,by=0,all.x=T)[,-1]
  rownames(pcoap) <- rownames(ec_pcoa$points)
      
   
    
    
  dev.copy2pdf(file=paste("./plots/",plot.title,".pdf",sep=""))
  dev.copy(png, file=paste("./plots/",plot.title,".png",sep=""), width=72*(7*4), 
    height=72*(8*4), res=72*4)
  dev.off()
  
  # Adonis (PERMANOVA)
  # Adonis runs a PERMANOVA (Created by Marti J. Anderson) 
  # this is very similar to ANOVA but for multivariate data
  # You can make very complex experimental designs with it
  # The default distance measure is bray-curtis, but other measures 
  # (Chao, Jaccard, Euclidean) can be used when specified  
#  Adonis <- adonis(sampleREL.dist ~ design$molecule*design$slope, method="bray", 
    permutations=1000)
#    return(Adonis)
  }
  