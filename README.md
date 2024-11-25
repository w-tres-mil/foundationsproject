1. **raw.R**
   - imports data from INKAR (https://www.inkar.de/) with the bonn R package (https://github.com/sumtxt/bonn/tree/main)
   - imports data from GERDA (https://www.german-elections.com/) with the gerda R package (https://www.german-elections.com/r-package/)
   - transforms the raw dta from INKAR into a data table
   - and saves the INKAR and GERDA data locally
2. **clean.R**
   - imports the INKAR and GERDA data tables from Github
   - merges the INKAR and GERDA data tables into a balanced panel data set data data_raw_final.dta
   - saves the data_raw_final.dta panel data set locally
