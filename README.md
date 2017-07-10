# WUENIC data
 
Scripts for importing the spreadsheets for WHO/UNICEF estimates of national immunization coverage and update the coverage estimates for the Modified Update in July 2016


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

1. From this link or into the repo, you can obtain the original Excel file called "coverage_estimates_series.xls"

2. The file "import_WUENIC_data.csv"  indicates which spreadheets and cells to import from the Excel file for the update

3. The file "best_estimate_scenario_modified_update_Jul2016.csv" indicates the scenarios where the coverage estimates should be updated in the coverage table for this modified update July 2016.


If the 3rd instruction is rather difficult, I can do it manually in R, as I have already selected the coverage from the relevant scenarios for the modified update. 





