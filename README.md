# WEUNIC--data-
 
Scripts for importing the spreadsheets for WHO/UNICEF estimates of national immunization coverage 


About the WHO/UNICEF estimates:

These estimates are based on data officially reported to WHO and UNICEF by Member States as well as data reported in the published and grey literature. 
These Coverage data are reviewed and the estimates updated annually for 195 countries

About this version:

WHO/UNICEF coverage estimates for 1980-2015, as of 15 July 2016.							
Last update: 3-March-2017 (data received as of 18-November-2016).
Next update: Mid July 2017

LINK:

http://apps.who.int/immunization_monitoring/globalsummary/timeseries/tswucoveragebcg.html

INSTRUCTIONS:

From this link, you can obtain the Excel file called "coverage_estimates"
In addition, in this repo you will find a file called "import_WUENIC_data.csv", with the instructions to the find information on the relevant spreadsheets (from the “coverage_estimates” Excel file) into Montagu


How the new WEUNIC coverage is going to be incorporated into the “coverage_table”?
The replacement of coverage values from WENIC data is going to be for activity_type “routine” and “with” gavi_support_level 
  
unique(cov$gavi_support_level)
[1] "hold2010" "with"     "none"     "without" 
unique(cov$activity_type)
[1] "routine" "campaign"




