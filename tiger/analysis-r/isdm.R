########################################
# Load packages or install packages if they don't exist
########################################

requiredPackages = c('raster',
                     'fields',
                     'mvtnorm',
                     'matrixStats', # matrix functions
                     'readr', # read files
                     'rgdal', 
                     'ggplot2', # visualization
                     'dplyr', # data manipularion
                     'tidyverse',
                     'rgbif', # import ad hoc data from GBIF
                     'tidyr' # data tidying
) 
for(p in requiredPackages){
  if(!require(p,character.only = TRUE)) install.packages(p)
  library(p,character.only = TRUE)
}

################################################################################
# AD HOC DATA AND COVARIATES FOR ALL GRIDS
################################################################################

setwd("/Users/chesterberry/mari/scl-obs-master/")

# ad hoc data
ad.hoc <- read.csv("tiger/data/prob 2/Ad Hoc v9 Sumatra 25NOV2019_V2_singleheader_srtm_hii.csv")
ad.hoc=cbind(rep(1, nrow(as.matrix(ad.hoc))), ad.hoc) # column of ones for observations

# rename and select variables
ad.hoc <- ad.hoc %>% select(gridcode = cell.label, 
                            hii = sumatragridmrgd2_centroids_hii_hii_1,
                            srtm = sumatragridmrgd2_centroids_srtm_srtm_1,
                            observation = "rep(1, nrow(as.matrix(ad.hoc)))")

# 1921 unique grid cells and 4covariates
ad.hoc.covariates <- read.csv("tiger/data/200130_Sumatragrid_covariates.csv")

# merge dataframes
# 1921 unique grid cells
ad.hoc.all <- plyr::join(ad.hoc, ad.hoc.covariates, by = "gridcode", type = "full")
# remove NA values
is.complete = which(is.na(ad.hoc.all$hii)==F &
                      is.na(ad.hoc.all$tri)==F &
                      is.na(ad.hoc.all$woody_cover)==F)
ad.hoc.all = ad.hoc.all[is.complete,]

# standardize covariates for all grid cells
means <- apply(ad.hoc.all[,c("hii","woody_cover","tri","distance_to_roads")],2,mean)
sds <- apply(ad.hoc.all[,c("hii","woody_cover","tri","distance_to_roads")],2,sd)
ad.hoc.all <- ad.hoc.all %>% mutate(hii = (hii - means[1])/sds[1],
                                    woody_cover = (woody_cover - means[2])/sds[2],
                                    tri = (tri - means[3])/sds[3],
                                    distance_to_roads = (distance_to_roads - means[4])/sds[4])

# needed for so.occupancy2 in CT model
woody.cover.hii.all <- ad.hoc.all %>% select(gridcode,
                                             hii,
                                             woody_cover)

# 29 unique grid cells
ad.hoc.29 <- merge(ad.hoc, ad.hoc.all, by="gridcode")
ad.hoc.29 <- ad.hoc.29 %>% select(gridcode, 
                                  hii = hii.x, 
                                  woody_cover, 
                                  distance_to_roads, 
                                  tri,
                                  observation=observation.y)

# standardize covariates?

# 1921 unique grid cells
pb.occupancy <- ad.hoc.all %>% select(hii,woody_cover)
pb.detection <- ad.hoc.all %>% select(tri,distance_to_roads)

# covariates that affect detection
# 1921 unique grid cells
X.back <- ad.hoc.all %>% select(hii,woody_cover)
X.back = cbind(rep(1, nrow(as.matrix(X.back))), X.back)
X.back <- X.back %>% select(observation = "rep(1, nrow(as.matrix(X.back)))",hii, woody_cover)
X.back <- as.matrix(X.back)

# covariates that affect detection
# 1921 unique grid cells
W.back <- ad.hoc.all %>% select(tri,distance_to_roads)
W.back = cbind(rep(1, nrow(as.matrix(W.back))), W.back)
W.back <- W.back %>% select(observation = "rep(1, nrow(as.matrix(W.back)))",tri,distance_to_roads)
W.back <- as.matrix(W.back)

# area in squared km
area.back = 1
s.area=area.back*nrow(X.back) #study area

# adding column of ones - po locations

ad.hoc.29 = cbind(rep(1, nrow(as.matrix(ad.hoc.29))), ad.hoc.29)

# 29 unique grid cells
X.po <- ad.hoc.29 %>% select(observation = "rep(1, nrow(as.matrix(ad.hoc.29)))", 
                             hii, 
                             woody_cover)
X.po <- as.matrix(X.po)
W.po <- ad.hoc.29 %>% select(observation = "rep(1, nrow(as.matrix(ad.hoc.29)))", 
                             tri, 
                             distance_to_roads)
W.po <- as.matrix(W.po)

################################################################################
# SITE OCCUPANCY
################################################################################

# 394 unique grid cells, 811 obs
s.o.original = read.csv("tiger/data/Tiger_observation_entry_9_SS_Observations_SUMATRA.csv")
so.occupancy <- read.csv("tiger/data/prob/Tiger_observation_entry_9_SS_Observations_SUMATRA_srtm_hii.csv")

# rename variables
s.o.original = rename(s.o.original, 
                      num.surveys = X..replicates.surveyed,
                      gridcode = grid.cell.label, 
                      replicate = replicate..)

s.o.original = s.o.original %>% select(-survey.id) # same on every column

#unique id on grid cell & replicate number
s.o.original$id.survey = cumsum(!duplicated(s.o.original[2:4])) 
# max(s.o.original$num.surveys) # 98

# get covariates by grid cell  - hii and woody_cover
s.o.subset<- s.o.original %>% select(gridcode) %>% distinct()
so.occupancy <- merge(woody.cover.hii.all, s.o.subset, by = c("gridcode"))
so.occupancy <- so.occupancy %>% select(-gridcode)

# Take all the surveys with NO signs
# create new row for each survey that took 
a = s.o.original %>% 
  filter(observation == 0) %>% 
  crossing(survey =(1:98)) %>% #max number of surveys done
  mutate(good.survey = ifelse(survey>num.surveys, NA, 1)) %>% 
  na.omit()
a = dplyr::select(a,-c(good.survey))

# expand the 1's
b = s.o.original %>% 
  filter(observation == 1) %>% 
  select(-observation) %>% 
  crossing(survey =(1:98)) %>% 
  mutate(good.survey = ifelse(survey>num.surveys, NA, 1)) %>%
  na.omit() %>%
  mutate(observation = ifelse(survey!=replicate, 0, 1))

b = dplyr::select(b,-c(good.survey)) 
#View(s.o.original)

# combine the two
so.filled =rbind(a,b)
so.filled_a = 
  dplyr::select(so.filled,-c(replicate)) %>%    
  distinct(survey,
           observation,
           id.survey,
           .keep_all = T)

#find the overlapping observations
onlyOnes = filter(so.filled_a, observation ==1)
onlyZs = filter(so.filled_a, observation == 0)

reps = plyr::match_df( 
  onlyZs,onlyOnes,
  on = c("id.survey","survey"))
# subtract overlapping observations from the expanded set
final.filled = setdiff(so.filled_a,reps)

strip.so = dplyr::select(final.filled,observation,survey,gridcode, id.survey)

y.so = spread(strip.so, survey, observation)

# remove variables grid and id.survey
y.so <- y.so %>% select(-gridcode, -id.survey)

# create new table with only two columns
temp = matrix(0,ncol = 2, nrow = dim(y.so)[1])
temp[,1] = rowSums(ifelse(is.na(y.so)==FALSE,1,0)) # number of times zero or one
temp[,2] = rowSums(ifelse(is.na(y.so)==FALSE & y.so == 1,1,0)) # number of times tiger was seen 

# remove NaNs
# is.complete = which(so.occupancy$hii != "NaN")
# 
# # only use complete cases
# so.occupancy = so.occupancy[is.complete,]

# temp=temp[is.complete,]# only use complete cases

y.so1 <- temp

area.so = pi*0.04

X.so1 = cbind(rep(1, nrow(as.matrix(so.occupancy))), so.occupancy) # 3 columns and 381 rows (2 columns are covariates)

################################################################################
# CAMERA TRAP 
################################################################################

##############
# Import CT 
##############

setwd("/Users/chesterberry/mari/scl-obs-master/")

# import shapefile of camera lat long and corresponding grid cells
# only includes grid cells for Puspurini data, not Leuser - 8 unique grid cells, 63 unique lat/lon values
unzip("tiger/data/camera_latlon_gridcode.zip")
camera.gridcode <- readOGR(dsn = ".", layer = "camera_latlon_gridcode")
camera.gridcode <- as.data.frame(camera.gridcode)
# rename and select variables
camera.gridcode <- camera.gridcode %>% mutate(camera.latitude = lat, 
                                              camera.longitude = lon) %>% 
                                        select(gridcode,
                                               camera.latitude,
                                               camera.longitude)

# BBSNP2015 CT data
# 31 unique deployments
tiger.CT.observations <- read.csv("tiger/data/Tiger_observation_entry_9_CT_observations_BBSNP_V2.csv")
# 68 unique deployments
tiger.CT.entry <- read.csv("tiger/data/Tiger_observation_entry_9_CT_deployments_latlon_BBSNP.csv")
# Leuser
unzip("tiger/data/tiger_sumatra_mvp_data.zip")
tiger.CT.observations2 <- read.csv("tiger/data/Tiger_observation_entry_9_CT_observations_Leuser.csv")
tiger.CT.entry2 <- read.csv("tiger/data/Tiger_observation_entry_9_CT_deployments_latlon_Leuser_V2.csv")
# remove NAs
tiger.CT.observations2 <- tiger.CT.observations2 %>% filter(project.ID == "Leuser CT2013")

# camera trap shapefile
ct.shp <- readOGR(dsn = "tiger/data/prob 2", layer = "Tiger_observation_entry_9_CT_deployments_latlon_BBSNP_celllabels")
ct.shp.df <- as.data.frame(ct.shp)

# Leuser data with gridcells
ct.leuser.shp <- readOGR(dsn = "tiger/data/prob 2", layer = "Tiger_observation_entry_9_CT_deployments_latlon_Leuser_V2_celllabels")
ct.leuser.df <- as.data.frame(ct.leuser.shp)

# rename and select camera trap variables
ct.shp.df <- ct.shp.df %>% mutate(deployment.ID = deployment,
                                  pickup.date.time = pickup.dat,
                                  deployment.date.time = deployme_1,
                                  camera.latitude = camera.lat,
                                  camera.longitude = camera.lon) %>% select(-grid)

# remove missing cameras - 5 obs
ct.shp.df <- ct.shp.df %>% filter(deployment.ID != c("BBS-2015-Loc-36") &
                                    deployment.ID != c("BBS-2015-Loc-37") &
                                    deployment.ID != c("BBS-2015-Loc-11")&
                                    deployment.ID != c("BBS-2015-Loc-12")&
                                    deployment.ID != c("BBS-2015-Loc-41"))

# rename and select camera trap variables
ct.leuser.df <- ct.leuser.df %>% mutate(deployment.ID = deployment,
                                  pickup.date.time = pickup.dat,
                                  deployment.date.time = deployme_1,
                                  camera.latitude = camera.lat,
                                  camera.longitude = camera.lon) %>% select(-grid)

# unique(ct.shp.df$camera.lon) # 63 unique lat/lon values

# factor variables
tiger.CT.observations2$deployment.ID <- as.factor(tiger.CT.observations2$deployment.ID)

# merge dfs to get observation times, pick up, deployment, and gridcode in one df
ct <- left_join(ct.shp.df, tiger.CT.observations, by = "deployment.ID")
ct2 <- left_join(ct.leuser.df, tiger.CT.observations2, by = "deployment.ID")

# select variables
ct <- ct %>% select(pickup.date.time,
                    deployment.date.time,
                    observation.date.time,
                    camera.latitude,
                    camera.longitude,
                    gridcode,
                    deployment.ID)

ct2 <- ct2 %>% select(pickup.date.time,
                    deployment.date.time,
                    observation.date.time,
                    camera.latitude,
                    camera.longitude,
                    gridcode,
                    deployment.ID)

ct <- rbind(ct, ct2)
# 395 observations for both camera trap datasets
# [1] "pickup.date.time"      "deployment.date.time"  "observation.date.time" "camera.latitude"      
# [5] "camera.longitude"      "gridcode"

# create a variable for the number of replicates per survey (one a day)
ct <- ct %>% mutate(# number of days between pick up and deployment
  num.surveys = as.Date(as.character(pickup.date.time), 
                        format="%Y/%m/%d")-
    as.Date(as.character(deployment.date.time), 
            format="%Y/%m/%d"),
  # the day that the tiger was observed
  replicate = as.Date(as.character(pickup.date.time), 
                      format="%Y/%m/%d")-
    as.Date(as.character(observation.date.time), 
            format="%m/%d/%Y"))

# remove hour minutes so that there is presence or absence for each day rather than multiple observations
ct$observation.date.time<-as.Date(as.POSIXct(ct$observation.date.time,format='%m/%d/%Y %H:%M'))

###### REMOVE DUPLICATES?????

# ct <- ct[!duplicated(ct[c(1,5)]),]
# ct <- ct %>% filter(pickup.datw != "NONE") # removes 5 missing cameras

# 215 observations
ct <- ct %>% distinct()
ct <- ct %>% select(-deployment.ID)

# add 0s for where a camera wasn't observed (listed as NAs)
ct$observation.date.time <- as.character(ct$observation.date.time)
ct$observation.date.time[is.na(ct$observation.date.time)] <- 0
ct <- ct %>% mutate(observation = ifelse(observation.date.time == 0, 0, 1))

# add 1s for where there was only one survey and no observation (listed as NAs)
ct$replicate <- as.character(ct$replicate)
ct$replicate[is.na(ct$replicate)] <- 0

ct <- ct %>% select(num.surveys,
                    gridcode,
                    observation.date.time, 
                    observation, 
                    replicate)

#unique id on grid cell & replicate number
ct$id.survey = cumsum(!duplicated(ct[2])) 

# make a copy
ct.merged <- ct 

# remove NA from num surveys
# 109 observations
ct.merged <- ct.merged %>% filter(num.surveys != "NA")
max(ct.merged$num.surveys) # 852 days expanded

# 30
ct.merged <- ct.merged %>% select(num.surveys,
                                  grid = gridcode,
                                  observation,
                                  replicate,
                                  id.survey)

# Take all the surveys with NO signs
# create new row for each survey that took 
a <- ct.merged %>% 
  filter(observation == 0) %>% 
  crossing(survey =(1:852)) %>% #max number of surveys done
  mutate(good.survey = ifelse(survey>num.surveys, NA, 1)) %>% 
  na.omit()
a <- dplyr::select(a,-c(good.survey))

# expand the 1's
b = ct.merged %>% 
  filter(observation == 1) %>% 
  select(-observation) %>% 
  crossing(survey =(1:852)) %>% 
  mutate(good.survey = ifelse(survey>num.surveys, NA, 1)) %>%
  na.omit() %>%
  mutate(observation = ifelse(survey!=replicate, 0, 1))

b = dplyr::select(b,-c(good.survey)) 

# combine the two
so.filled =rbind(a,b)
so.filled_a = 
  dplyr::select(so.filled,-c(replicate)) %>%    
  distinct(survey,
           observation,
           id.survey,
           .keep_all = T)

#find the overlapping observations
onlyOnes = filter(so.filled_a, observation ==1)
onlyZs = filter(so.filled_a, observation == 0)

reps = plyr::match_df( 
  onlyZs,onlyOnes,
  on = c("id.survey","survey"))
# subtract overlapping observations from the expanded set
final.filled = setdiff(so.filled_a,reps)

strip.so = dplyr::select(final.filled,observation,survey,grid, id.survey)

y.ct = spread(strip.so, survey, observation)

# remove variables grid and id.survey
y.ct2 <- y.ct %>% select(-grid, -id.survey)
y.ct <- y.ct %>% select(grid)

# exactly what we did in the so model
# create new table with only two columns
temp = matrix(0,ncol = 2, nrow = dim(y.ct2)[1])
temp[,1] = rowSums(ifelse(is.na(y.ct2)==FALSE,1,0)) # number of times zero or one
temp[,2] = rowSums(ifelse(is.na(y.ct2)==FALSE & y.ct2 == 1,1,0)) # number of times tiger was seen 

# temp=temp[is.complete,]# only use complete cases

y.so2 <- temp 

area.so = 1

##############
# so.occupancy2
##############

ct.subset <- y.ct %>% select(gridcode = grid)

so.occupancy2 <- merge(woody.cover.hii.all, ct.subset, by = c("gridcode"))

# so.occupancy2 <- merge(ct.shp.df, so.occupancy2, by = c("gridcode")) %>% distinct()
so.occupancy2 <- so.occupancy2 %>% select(hii, woody_cover)

# standardize
so.occupancy2 <- so.occupancy2 %>% mutate(hii = (hii - means[1])/sds[1],
                                          woody_cover = (woody_cover - means[2])/sds[2])

X.so2 = cbind(rep(1, nrow(as.matrix(so.occupancy2))), so.occupancy2) 

################################################################################
# ANALYSIS
################################################################################

# SITE OCCUPANCY
so.fit=so.model(X.so=X.so1,y.so=y.so1)
so.fit
# $coefs
# Parameter name      Value Standard error
# 1          beta0 -0.7248378     0.16827843
# 2            hii  0.1594643     0.11495585
# 3    woody_cover  0.8728821     0.19321552
# 4 alphaintercept -2.5062539     0.04591906
# 
# $convergence
# [1] 0
# 
# $value
# [1] 2388.365

# CAMERA TRAP
ct.fit=so.model(X.so=X.so2,y.so=y.so2)
ct.fit
# $coefs
# Parameter name      Value Standard error
# 1          beta0 -0.3266466     97.6257821
# 2            hii -1.1504321      4.0573230
# 3    woody_cover  1.5604929     50.8323994
# 4 alphaintercept -2.8131726      0.1340841
# 
# $convergence
# [1] 0
# 
# $value
# [1] 236.2238

# AD HOC
pb.fit=pb.ipp(X.po=X.po, W.po=W.po, X.back=X.back, W.back=W.back)
pb.fit
# $coefs
# Parameter name      Value
# 1             beta0 -192.66095
# 2               hii  142.92509
# 3       woody_cover  155.18525
# 4            alpha0 -209.95196
# 5               tri   10.48055
# 6 distance_to_roads   98.64668
# 
# $convergence
# [1] 0
# 
# $value
# [1] -38237.2

# INTEGRATED 
# data issue, no SE
integrated.fit=pbso.integrated(X.po, W.po, X.back, W.back, X.so1, X.so2, y.so1, y.so2)
integrated.fit
# $coefs
# Parameter name      Value Standard error
# 1             beta0  15.311190             NA
# 2               hii  13.821215             NA
# 3       woody_cover   9.543099             NA
# 4            alpha0 -56.635702             NA
# 5               tri   4.607397             NA
# 6 distance_to_roads   9.556901             NA
# 7            alpha1  -2.851738             NA
# 8            alpha2  -2.762765             NA
# 
# $convergence
# [1] 0
# 
# $value
# [1] -578.012
