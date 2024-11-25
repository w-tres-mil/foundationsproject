library(httr)
library(haven)
library(data.table)
library(tidyverse)
# GitHub configuration

repo_owner <- readline(prompt = "Enter the repo owner: ")
repo_name <- readline(prompt = "Enter the repo name: ")
access_token <- readline(prompt = "Enter your GitHub personal access token: ")

# Define the function
git <- function(file_path) {
  # Construct the URL for the GitHub API
  url <- sprintf(
    "https://api.github.com/repos/%s/%s/contents/%s",
    repo_owner, repo_name, file_path
  )
  
  # Request the file content
  response <- GET(
    url,
    add_headers(Authorization = sprintf("token %s", access_token)),
    accept("application/vnd.github.v3.raw")
  )
  
  # Check for successful request
  if (response$status_code == 200) {
    # Save the file locally (optional)
    temp_file <- tempfile(fileext = ".dta")
    writeBin(content(response, "raw"), temp_file)
    
    # Read the Stata file into R
    data <- read_dta(temp_file)
    
    # Remove the temporary file (optional)
    unlink(temp_file)
    
    # Return the data
    return(data)
  } else {
    stop("Failed to download the file. Check your credentials and file path.")
  }
}

#import data

y = git("dependent_raw.dta")
X = git("independent_raw.dta")

#clean data

#clean independent variables
X_wide = X %>%
  rename(year = Zeit) %>%
  rename(id = Schlüssel) %>%
  pivot_wider(names_from = Indikator,values_from = Wert) %>%
  select(-Raumbezug) %>%
  mutate(year = as.numeric(year))

#clean results
y_temp = y %>%
  rename(year = election_year) %>%
  rename(id = county_code) %>%
  select(-flag_unsuccessful_naive_merge) %>%
  select(-far_right) %>%
  select(-far_left) %>%
  select(-far_left_w_linke) %>%
  select(-cdu_csu)
parties = 9:112
i = y_temp %>%
  filter(id==11000,year==2021) %>%
  mutate(across(all_of(parties), ~ . * valid_votes)) %>%
  mutate(turnout = turnout*eligible_voters)
parties = 11:114
r <- i %>%
  group_by(id, state, year, population,area) %>%
  filter(row_number() %in% c(1, 2)) %>%  
  summarise(across(everything(), sum, na.rm = TRUE), .groups = 'drop') %>%
  mutate(across(all_of(parties),~ . / valid_votes)) %>%
  mutate(turnout = turnout/eligible_voters)
m = y_temp %>%
  filter(!(id==11000&year==2021))
yt = setDT(rbind(m,r))
yt[,eyear:=year]

#create lagged results
yl = copy(yt)
setnames(yl,old=colnames(yt),new=paste0("l",colnames(yt)))
yl[lyear==2021,lyear:=2025
   ][lyear==2017,lyear:=2021
     ][lyear==2013,lyear:=2017
       ][lyear==2009,lyear:=2013
         ][lyear==2005,lyear:=2009
           ][lyear==2002,lyear:=2005
             ][lyear==1998,lyear:=2002
               ][lyear==1994,lyear:=1998
                 ][lyear==1990,lyear:=1994]
setnames(yl,old=c("lid","lyear","lstate"),new=c("id","year","state"))

#merge results and lagged results
y_final = setDT(merge(yt,yl, by=c("id","year","state"),all=TRUE))

#create data raw

data_raw_final = setDT(merge(y_final,X_wide,by=c("id","year"),all.y=TRUE))

setnames(data_raw_final,old=colnames(data_raw_final),new=paste0("v",colnames(data_raw_final)))
write_dta(data_raw_final,"/Users/tracemiller/Documents/bocconi courses/foundation/assignment group/data_raw_final.dta")

#create data base

data_base = setDT(merge(y_final,X_wide,by=c("id","year"),all.y=TRUE))

data_base[year==1996|year==2000|year==2003|year==2007|year==2011|year==2015|year==2019,lag:=2
][year==1997|year==2001|year==2004|year==2008|year==2012|year==2016|year==2020,lag:=1
][year==1998|year==2002|year==2005|year==2009|year==2013|year==2017|year==2021,lag:=0
  ][year>=1996&year<=1998,eyear:=1998
  ][year>=2000&year<=2002,eyear:=2002
  ][year>=2003&year<=2005,eyear:=2005
  ][year>=2007&year<=2009,eyear:=2009
  ][year>=2011&year<=2013,eyear:=2013
  ][year>=2015&year<=2017,eyear:=2017
  ][year>=2019&year<=2021,eyear:=2021]

data_base_final = data_base[,-c("195","196","197","198","199","200","201","202")][lag==0]

setnames(data_base_final,old=colnames(data_base_final),new=paste0("v",colnames(data_base_final)))
write_dta(data_base_final,"/Users/tracemiller/Documents/bocconi courses/foundation/assignment group/data_base_final.dta")

#create data lagd

X_lagd = setDT(copy(X_wide))
X_lagd[,year:=year+3]

data_lagd = setDT(merge(y_final,X_lagd,by=c("id","year"),all.y=TRUE))

data_lagd = data_lagd[year==1996|year==2000|year==2003|year==2007|year==2011|year==2015|year==2019|year==2023,lag:=2
][year==1997|year==2001|year==2004|year==2008|year==2012|year==2016|year==2020|year==2024,lag:=1
][year==1998|year==2002|year==2005|year==2009|year==2013|year==2017|year==2021|year==2025,lag:=0
  ][year>=1996&year<=1998,eyear:=1998
  ][year>=2000&year<=2002,eyear:=2002
  ][year>=2003&year<=2005,eyear:=2005
  ][year>=2007&year<=2009,eyear:=2009
  ][year>=2011&year<=2013,eyear:=2013
  ][year>=2015&year<=2017,eyear:=2017
  ][year>=2019&year<=2021,eyear:=2021
  ][year>2022&year<=2025,eyear:=2025]

data_lagd_final = data_lagd[,-c("195","196","197","198","199","200","201","202")][lag==0|year==2025]

setnames(data_lagd_final,old=colnames(data_lagd_final),new=paste0("v",colnames(data_lagd_final)))
write_dta(data_lagd_final,"/Users/tracemiller/Documents/bocconi courses/foundation/assignment group/data_lagd_final.dta")

#create data base wide

data_base_wide = data_base %>%
  relocate(eyear, .after = year) %>%
  select(-year) %>%
  select(-state) %>%
  drop_na(lag) %>%
  drop_na(eyear) %>%
  pivot_wider(names_from = lag,values_from = "eligible_voters":"451")

setnames(data_base_wide,old=colnames(data_base_wide),new=paste0("v",colnames(data_base_wide)))
write_dta(data_base_wide,"/Users/tracemiller/Documents/bocconi courses/foundation/assignment group/data_base_wide_final.dta")

#create data lag wide 

data_lagd_wide = data_lagd %>%
  relocate(eyear, .after = year) %>%
  select(-year) %>%
  select(-state) %>%
  drop_na(lag) %>%
  drop_na(eyear) %>%
  pivot_wider(names_from = lag,values_from = "eligible_voters":"451")

setnames(data_lagd_wide,old=colnames(data_lagd_wide),new=paste0("v",colnames(data_lagd_wide)))
write_dta(data_lagd_wide,"/Users/tracemiller/Documents/bocconi courses/foundation/assignment group/data_lagd_wide_final.dta")


