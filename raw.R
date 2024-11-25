devtools::install_github("hhilbig/gerda")
remotes::install_github("sumtxt/bonn", force=TRUE)

library(bonn)
library(gerda)
library(data.table)
library(tidyverse)
library(haven)

library(httr)
library(jsonlite)

library(purrr)
library(furrr)

library(parallel)
library(future)

library(pbapply)

#import independent variables

themes = get_themes(geography="KRE")

t = themes$ID

variables = list()

for (i in t) {
  variable = get_variables(theme = i,geography = "KRE")
  variables[[i]] = variable
}

variables = rbindlist(variables, use.names = TRUE, fill = TRUE)

v = variables$Gruppe

data = list()

num_cores <- detectCores() - 1
cl <- makeCluster(num_cores)

clusterExport(cl, c("get_data", "v"))

data <- pblapply(v, function(i) get_data(variable = i, geography = "KRE"), cl = cl)

stopCluster(cl)

independent_raw = rbindlist(data,use.names=TRUE,fill=TRUE)

#import dependent variables

dependent_raw = load_gerda_web("federal_cty_harm", verbose = FALSE, file_format = "rds")

#save
#edit address in order to save local

write_dta(independent_raw, "/Users/tracemiller/Documents/bocconi courses/foundation/assignment group/independent_raw.dta")

write_dta(dependent_raw,"/Users/tracemiller/Documents/bocconi courses/foundation/assignment group/dependent_raw.dta")



