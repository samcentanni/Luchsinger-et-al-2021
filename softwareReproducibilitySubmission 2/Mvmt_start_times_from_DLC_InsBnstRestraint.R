library(tidyverse)

#Mvmt_start_times_from_DLC

# Read_to_tibble
# file_path = path of .csv from DLC
read_to_tibble <- function(file_path, subj_num, subj_date, threshold){
  read.csv(file_path, skip = 1, header = F, stringsAsFactors = FALSE) %>%
    as_tibble() %>%
    dplyr::rename(frame_num = 1, Green_Tape_x = 2, Green_Tape_y = 3, Green_Tape_likelihood = 4,	Tip_Tail_x = 5,	Tip_Tail_y = 6,	Tip_Tail_likelihood = 7) %>%
    slice(-1:-2) %>%
    mutate(subject_num = subj_num, subject_date = subj_date) %>%
    lapply(as.numeric) %>%
    as_tibble() %>%
    select(subject_num, subject_date, everything()) %>%
    filter(Tip_Tail_likelihood >= threshold) %>%
    filter(Green_Tape_likelihood >= threshold)
  }


#Pythag therom 
#x1 = initial x position
#x2 = next fram x position from offset data
#y1 = initial y position
#y2 = next fram y position from offset data

Pythat_ther <- function(x1, x2, y1, y2){
  sqrt((x1 - x2[-length(x2)])^2 + ( y1 - y2[-length(y2)])^2)
} 



# Get subj number and date
# subj_num_pattern = the pattern surounding the subject number (.*?) indicates any 
# charicrar string of anylenght will be used. place the pattern that comes before and after the subj number on either side of the (.*?). [e.g. "Subject(.*?)-"]
subj_num_fx <- function(subj_num_pattern, file_path){
  regmatches(file_path, regexec(subj_num_pattern,file_path))[[1]][2]
  
}

# Get subj number and date
# file_path = the path for the file which will be used to pull out the naming info. Same rules as subj_num_fx [e.g. "Restraint-(.*?)_Subject"]
subj_date_fx <- function(subj_date_pattern, file_path){
  regmatches(file_path, regexec(subj_date_pattern,file_path))[[1]][2]
  
}

# Create column with movement (true or false)
# can set SD threshold 
isMovement <- function(speed, sd, sdThreshold) {
  speed >= sd * sdThreshold
}

# Velocity to run lenght
# tracker = the mvmt file for the object that is being tracked. [e.g. pos_data$Green_mvnt]
# output to be called runlen
vel_to_runlen <- function(tracker){
  rle(tracker)
}



# runlen_to_raw_start_end
# output = raw_mvmt
runlen_to_raw_start_stop <- function(start, end, runlen){
  runlen %>% unclass() %>%
    as_tibble(runlen$lengths) %>%
    cbind(runlen$values) %>%
    cbind(start, end) %>%
    rename(raw_movement = values)
}

######
# vel_to_raw 
######
# Large function that takes velocity data to raw movement data
vel_to_raw <- function(tracker){
  runlen <- vel_to_runlen(tracker)
  
  # Compute endpoints of run
  end = cumsum(runlen$lengths) 
  start = c(1, lag(end)[-1] + 1) 
  
  raw_mvmt <- runlen_to_raw_start_stop(start, end, runlen)
  return(raw_mvmt)
}


# remove_gaps
# output = no_gaps
remove_gaps <- function(raw_mvmt, maxgap){
  raw_mvmt$movement_clean <- NA
  raw_mvmt$movement_clean <- ifelse((raw_mvmt$lengths <= maxgap) & (raw_mvmt$raw_movement != TRUE), TRUE, raw_mvmt$raw_movement)
  return(raw_mvmt$movement_clean)
}




# nogaps_to_clean
nogaps_to_clean <- function(no_gaps, start_end_endpoints){
  no_gaps$start[start_end_endpoints$start_clean] %>%
    cbind(no_gaps$end[start_end_endpoints$end_clean])
}
  
#####
# RAW to CLEAN
# also labels body part, dif in start/stop time, date, active status
#####
raw_to_clean <- function(raw_mvmt, maxgap, subj_date, label, seconds){
  #convert maxgap to ms
  maxgap <- maxgap * 10
  
  #no gaps
  raw_mvmt$movement_clean <- NA
  raw_mvmt$movement_clean <- remove_gaps(raw_mvmt, maxgap)
  
  ### calculate rle of no_gaps 
  rle_mvmt2 <- rle(raw_mvmt$movement_clean) 
  

  # Compute endpoints of run
  end_clean = cumsum(rle_mvmt2$lengths) 
  start_clean = c(1, lag(end_clean)[-1] + 1) 
  start_end_endpoints <- data.frame(start_clean, end_clean)

  
  # clean the start and endpoints
  clean <- nogaps_to_clean(raw_mvmt, start_end_endpoints) 
  colnames(clean) <- c("start", "end")
  clean <- as.data.frame(clean)
  clean$start <- seconds[clean$start]
  clean$end <- seconds[clean$end]
  print(clean)
  
  # convert times from ms to s, return as tibble instead of vector
  # clean <- clean *.1 #dont need this because step above now takes care of it
  clean <- as_tibble(clean)
  
  #label body part, dif in start/stop time, date, active status
  clean$bodypart <- c(label)
  clean$diff <- clean$end - clean$start
  clean$date <- c(subj_date)
  clean$active <- rep_len(c(rle_mvmt2$values[1], rle_mvmt2$values[2]), length.out = length(clean$start))

  return(clean)
}

# active_only 
# returns only active 
active_only <- function(clean) {
  filter(clean, clean$active == TRUE)
}


# inactive_only 
# returns only inactive 
inactive_only <- function(clean) {
  filter(clean, clean$active == FALSE)
}


# adds subject num col 
#
# 1 through 9 GCaMP7
# 10 through 14 GABASnFr
addLabels <- function(allClean, subj_num) {
  allClean %>%
    mutate(subj_num = subj_num) %>%
    mutate(type = ifelse(as.numeric(subj_num) < 20, "GCaMP7", "GABASnF"))
}

# takes dataset and makes it tidy by converting to true long form data format
# ie start and end cols -> event col with "start" or "end" row vals
tidyCleanData <- function(allClean) {
  allClean %>% select(-diff) %>%
    gather(key="action", value="time", start, end) %>%
    arrange(time) %>%
    filter(active==TRUE) %>%
    select(-active) %>%
    mutate(headStartCount = cumsum(bodypart=="Green_Tape" & action=="start")) %>%
    mutate(headEndCount = cumsum((bodypart=="Green_Tape" & action=="end"))) %>%
    mutate(headMoving = ((headStartCount > headEndCount) | (bodypart=="Green_Tape" & action =="end"))) %>%
    mutate(tailStartCount = cumsum(bodypart=="Tail_Tip" & action=="start")) %>%
    mutate(tailEndCount = cumsum((bodypart=="Tail_Tip" & action=="end"))) %>%
    mutate(tailMoving = ((tailStartCount > tailEndCount) | (bodypart=="Tail_Tip" & action =="end"))) %>%
    group_by(headStartCount, headMoving) %>%
    mutate(lengthOfHeadMovement = ifelse(headMoving==TRUE, max(time)-min(time), 0.0)) %>%
    ungroup() %>%
    group_by(tailStartCount, tailMoving) %>%
    mutate(lengthOfTailMovement = ifelse(tailMoving==TRUE, max(time)-min(time), 0.0)) %>%
    ungroup() %>%
    select(time, action, bodypart, headMoving, tailMoving, lengthOfHeadMovement, lengthOfTailMovement, everything())
}

# labels large movement data 
findLargeMovements <- function(tidiedAllClean) {
  tidiedAllClean %>%
    mutate(allMovementStartCount = headStartCount + tailStartCount) %>%
    mutate(allMovementEndCount = headEndCount + tailEndCount) %>%
    mutate(bodypartMoving = (allMovementStartCount > allMovementEndCount)) %>%
    filter(bodypart=="Tail_Tip" | bodypart=="Green_Tape") %>%
    mutate(movementID = ifelse(bodypartMoving==FALSE, cumsum(bodypartMoving==FALSE) - 1, cumsum(bodypartMoving==FALSE))) %>%
    group_by(movementID) %>%
    mutate(largeMovement = (ifelse(max(allMovementStartCount) - min(allMovementEndCount) > 1, TRUE, FALSE))) %>%
    ungroup() %>%
    group_by(largeMovement, movementID) %>%
    mutate(largeMovementStart = min(time)) %>%
    mutate(largeMovementEnd = max(time)) %>%
    ungroup() 
}

# filters large movement data into one df
filterLarge <- function(tidiedAllClean) {
    findLargeMovements(tidiedAllClean) %>%
    filter(largeMovement==TRUE) %>%
    mutate(lengthOfLargeMovement = largeMovementEnd - largeMovementStart) %>%
    select(time, action, bodypart, largeMovementStart, largeMovementEnd, lengthOfLargeMovement, lengthOfHeadMovement, lengthOfTailMovement, subj_num, date, type)
}

# filters head only data into one df
filterSmall <- function(tidiedAllClean) {
  findLargeMovements(tidiedAllClean) %>%
    select(-largeMovementEnd, -largeMovementStart) %>%
    filter(headMoving==TRUE & largeMovement==FALSE) %>%
    select(time, action, bodypart, lengthOfHeadMovement, subj_num, date, type)
}

# filters tail only movements into one df
filterTailOnly <- function(tidiedAllClean) {
  findLargeMovements(tidiedAllClean) %>%
    select(-largeMovementEnd, -largeMovementStart) %>%
    filter(tailMoving==TRUE & largeMovement==FALSE) %>%
    select(time, action, bodypart, lengthOfTailMovement, subj_num, date, type)
}

# pull only start values for large movement data
grabLargeStarts <- function(largeMovements) {
  largeMovements %>% 
  group_by(largeMovementStart) %>%
  summarize() 
}

# pull just the start values for either tail only or head only data
grabSingleStarts <- function(movements) {
  movements %>% 
    filter(action=="start") %>%
    select(time)
}

# pull just the start values for either tail only or head only data
grabSingleEnds <- function(movements) {
  movements %>% 
    filter(action=="end") %>%
    select(time)
}

# ensures filepath exists and created directory if it does not 
checkFilePath <- function(fileStem, subj_date, subj_num) {
  if(!file.exists(fileStem)) {
    dir.create(file.path(fileStem))
  }
  
  filePath <- paste(fileStem, '/Restraint-', subj_date, '/', sep="") %>% file.path()
  if(!file.exists(filePath)) {
    dir.create(file.path(filePath))
  }
  
  subFolderPath <- paste(fileStem, '/Restraint-', subj_date, '/Subject-', subj_num, '-', subj_date, '/', sep="") %>% file.path()
  if(!file.exists(subFolderPath)) {
    dir.create(file.path(subFolderPath))
  }
}
