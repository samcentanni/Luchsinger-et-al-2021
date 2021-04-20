# Set the working directory to the location of the example folder provided to reviewers. 
setwd("/Users/exampUser/Desktop/Projects/inProgress/ActiveCoping/code/softwareReproducibilitySubmission") 

source("Mvmt_start_times_from_DLC_InsBnstRestraint.R")

# creating empty df that will become df with all movements
allMovements <- data.frame(
  time=numeric(),
  action=character(),
  bodypart=character(),
  diff=numeric(),
  date=numeric(),
  active=logical(),
  subj_num=numeric(),
  type=character(),
  stringsAsFactors=FALSE
)

# looping through all files in a directory
experiment <- "PKCd_restraint"
path = "./example_data/"

file.names <- dir(path, pattern =".csv")

i = 1
for(i in 1:length(file.names)) {

file_location <- paste(path,file.names[i], sep="")

# Create column with subj number and date
subj_num <- subj_num_fx("1030_(.*?)-", file_location)

# Create column with subj number and date
subj_date <- subj_date_fx("aint-(.*?)_", file_location)

# set threshold for confidence level 
confThreshold <- 0.1

# Read to tibble
pos_data <- read_to_tibble(file_location, subj_num, subj_date, confThreshold)

# Create data offset by 1 frame to calc movement between data frames.
data_offset <- add_row(pos_data, .before = 1)

# Calc speed for each marker
pos_data <- mutate(pos_data,
               Green_Tape_speed = Pythat_ther(pos_data$Green_Tape_x,data_offset$Green_Tape_x, pos_data$Green_Tape_y, data_offset$Green_Tape_y),
               Tip_Tail_speed = Pythat_ther(pos_data$Tip_Tail_x, data_offset$Tip_Tail_x,  pos_data$Tip_Tail_y, data_offset$Tip_Tail_y),
               seconds = pos_data$frame_num *.1
              )

# Replace NA's with 0's
pos_data[is.na(pos_data)] <- 0

# Calc standard deviation for each marker
pos_data <- mutate(pos_data,
               GT_speed_sd = sd(pos_data$Green_Tape_speed),
               Tail_speed_sd = sd(pos_data$Tip_Tail_speed)
)


# set threshold for sd 
sdThreshold <- 1

# Create column with movement (true or false)
pos_data$Green_mvnt <-  isMovement(pos_data$Green_Tape_speed, pos_data$GT_speed_sd, sdThreshold) 
pos_data$Tail_mvmt <- isMovement(pos_data$Tip_Tail_speed, pos_data$Tail_speed_sd, sdThreshold)


# set maximum gap to define movements
maxgap <- .7

# clean start and stop times for each marker

cleanGreen <- raw_to_clean(vel_to_raw(pos_data$Green_mvnt), maxgap, subj_date, "Green_Tape", pos_data$seconds)
cleanTail <- raw_to_clean(vel_to_raw(pos_data$Tail_mvmt), maxgap, subj_date, "Tail_Tip", pos_data$seconds)


# pull active intervals
green_active <- active_only(cleanGreen)
tail_active <- active_only(cleanTail)

# pull inactive intervals
green_inactive <- inactive_only(cleanGreen)
tail_inactive <- inactive_only(cleanTail)

# clean data from each marker appended into one df
allClean <- bind_rows(
  cleanGreen,
  cleanTail
)

# adds labels; clean but not tidy yet
allClean <- addLabels(allClean, subj_num)

# this labelled df will be added to "allMovements"
tidiedAllClean <- tidyCleanData(allClean)

# filter types of movements and pull start times for each type
largeMovements <- filterLarge(tidiedAllClean)
largeStart <- grabLargeStarts(largeMovements)

smallMovements <- filterSmall(tidiedAllClean)
smallStart <- grabSingleStarts(smallMovements)
smallEnd <- grabSingleEnds(smallMovements)

tailOnlyMovements <- filterTailOnly(tidiedAllClean)
tailOnlyStart <- grabSingleStarts(tailOnlyMovements)
tailOnlyEnd <- grabSingleEnds(tailOnlyMovements)

# append to large df
allMovements <- rbind(allMovements, tidiedAllClean)



####### writing files #######
fileStem <- paste('./', experiment, sep="") %>% file.path()

# ensures directory exists 
checkFilePath(fileStem, subj_date, subj_num)

fileLarge <-  paste(fileStem, '/Restraint-', subj_date, '/Subject-', subj_num, '-', subj_date, '/whole_body_mvmt_start_times.csv', sep="") %>% file.path()
fileSmall <- paste(fileStem, '/Restraint-', subj_date, '/Subject-', subj_num, '-', subj_date, '/head_only_mvmt_start_times.csv', sep="") %>% file.path()
fileTail <-  paste(fileStem, '/Restraint-', subj_date, '/Subject-', subj_num, '-', subj_date, '/tail_only_mvmt_start_times.csv', sep="") %>% file.path()
fileGraph <- paste(fileStem, '/Restraint-', subj_date, '/Subject-', subj_num, '-', subj_date, sep="") %>% file.path()

write.table(largeStart, sep = ",", file = fileLarge, col.names=FALSE, row.names = FALSE)
write.table(smallStart, sep = ",", file = fileSmall, col.names=FALSE, row.names = FALSE)
write.table(tailOnlyStart, sep = ",", file = fileTail, col.names=FALSE, row.names = FALSE)

ggplot(pos_data)+
  geom_line(aes(x = frame_num/10, y = Green_Tape_speed), color = "darkblue", size = .35, alpha = .5)+
  geom_line(aes(x = frame_num/10, y = Tip_Tail_speed), color = "darkred", size = .35, alpha = .5)+
  theme_bw() + 
  scale_y_continuous(name = "Speed", expand = c(0,0))+ 
  scale_x_continuous(name = "Time (Minutes)",
                     breaks = c(0, 300, 600, 900, 1200,1500, 1800), #breaks are where the ticks go
                     labels = c(0, 5, 10, 15, 20, 25, 30)) +  #labels are how the ticks are labeled
  # xlim(1700, 1800)+
  annotate("rect", 
           xmin = largeMovements$largeMovementStart,
           xmax = largeMovements$largeMovementEnd, 
           ymin = 0,
           ymax = Inf, 
           fill = "purple", 
           alpha = .05)+
  annotate("rect",
           xmin = smallStart$time,
           xmax = smallEnd$time,
           ymin = 0,
           ymax = Inf,
           fill = "blue",
           alpha = .25)+
  annotate("rect",
           xmin = tailOnlyStart$time,
           xmax = tailOnlyEnd$time,
           ymin = 0,
           ymax = Inf,
           fill = "red",
           alpha = .4)
# facet_zoom(x = frame_num/10 > 1000 & frame_num/10 < 1200, split = FALSE, horizontal = FALSE, zoom.size = 1.25, show.area = TRUE, shrink = FALSE)

ggsave(path = fileGraph, filename =  'graph_restraint_600.png', width = 8, height = 3, units = "in", dpi =600)  #600 DPI for publications

}




