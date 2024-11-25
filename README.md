1. **raw.R**
   - imports data from INKAR (https://www.inkar.de/) with the bonn R package (https://github.com/sumtxt/bonn/tree/main)
   - imports data from GERDA (https://www.german-elections.com/) with the gerda R package (https://www.german-elections.com/r-package/)
   - transforms the raw dta from INKAR into a data table
   - and saves the INKAR and GERDA data locally
3. **clean.R**
   - imports the INKAR and GERDA data tables from Github
   - merges the INKAR and GERDA data tables into a balanced panel data set data data_raw_final.dta
   - saves the data_raw_final.dta panel data set locally
4. **analysis0.R**
  - imports the data_raw_final.dta panel data set from Github
  - runs the custom elastic net function and selects the optimal hyperparameters
  - outputs a list of covariates selected
  - outputs a data table of predicted election results, actual election results, the difference, and the mean squared error at the county level
4. **analysis1.R**, **analysis2.R**, **analysis3.R**
  - import the data_raw_final.dta panel data set from Github
  - create lags of one, two, and three years, respectively
  - run the custom elastic net function and selects the optimal hyperparameters
  - output a list of covariates selected
  - output a data table of predicted election results, actual election results, the difference, and the mean squared error at the county level
5. **analysis1d.R**
  - imports the data_raw_final panel data set from Github
  - creates lag of one year
  - creates Eastern Germany dummy
  - runs the custom elastic net function and selects the optimal hyperparameters
  - outputs a list of covariates selected
  - outputs a data table of predicted election results, actual election results, the difference, adn the mean squared error at the county level
6. **analysis1db.R**
  - imports the data_raw_final panel data set from Github
  - creates lag of one year
  - creates Eastern Germany dummy
  - creates Berlin dummy
  - runs the custom elastic net function and selects the optimal hyperparameters
  - outputs a list of covariates selected
  - outputs a data table of predicted election results, actual election results, the difference, adn the mean squared error at the county level
