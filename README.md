# Luchsinger-et-al-2021
Introduction:
This program is meant to calculate speed and identify movement bouts.
In short, it takes the DeepLabCut position files and calculates the tracked objects’ relative speed. It then identifies coping bouts based on a movement threshold.

System Requirements:
This code has been tested on macOS Mojave (10.4) - macOS Catalina (10.15.7) using R version 3.6.1 and the Tidyverse package.


Installation Guide:
Typical install time on a "normal" desktop computer: 10-20 min.

After installing R (https://rstudio.com/products/rstudio/), Tidyverse can be installed by typing

	install.packages("tidyverse")

into the R console.

Demo:
1) Open the boutTimeWorkflowPKCd.R script.

2) Change the working directory to the location of the "softwareReproducibilitySubmission" folder provided to reviewers. This can be set by changing the path in the code (line 2). 

	setwd("/Users/exampUser/Desktop/Projects/inProgress/ActiveCoping/code/softwareReproducibilitySubmission") 

3) Change the value being stored as an experiment to an identifier of your choosing. In the example below, it is set to PKCd_restraint (line 20).

	experiment <- "PKCd_restraint"

4) Change the path variable to the path to the folder containing the DLC movement files (line 21). (In this example, you will not need to change this as it already points to the the "example_data" folder in the working directory as shown below).
	
	path = "./example_data/"

5) Run all lines of the boutTimeWorkflowPKCd.R code.

6) Once complete, the following folders will be created inside the working directory.

	PKCd_restraint>Restraint-191030>Subject-Subject5-191030

In this folder, there will be separate .csv files for the start times for:
	a) head only movements,
	b) tail only movements, and
	c) whole-body movements.

It will also produce a .png of the entire trace that shows the speed of the tracked points and the identified movement bouts.
(This should take a matter of seconds.)

You can compare your results to the expected output that is in the provided "Expected_Output" folder. 

These start times were then used in the open-source MatLab code available from TDT (https://www.tdt.com/support/matlab-sdk/). We have included a slightly modified version that works with the time-locked output output files from the pipeline above the the TDTFiles folder. The instructions on how to use each of these can be found in their respective MatLab files (e.g. Photometry_data_processingFreq.m, Winder_Pipeline_TimeLock_DLC.m) 



Instructions for use:
The code should be relatively easy to run on similarly organized DLC data. Simply point the path to a folder containing the similarly formatted DLC data.



