library(haven)
library(glmnet)
library(plm)
library(httr)
library(curl)
library(dplyr)
library(tidyr)
library(glmnet)

repo_owner <- readline(prompt = "Enter the repo owner: ")
repo_name <- readline(prompt = "Enter the repo name: ")
access_token <- readline(prompt = "Enter your GitHub personal access token: ")

set.seed(123)

# Define the function----
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

raw = git("data_raw_final.dta")

# Create a new data frame for 2025 rows
data_2025 <- raw %>%
  distinct(vid) %>%  # Keep only unique `vid` values
  mutate(vyear = 2025)  # Add the year 2025

# Combine the original data with the new 2025 rows
raw_with_2025 <- raw %>%
  bind_rows(data_2025) %>%
  arrange(vid, vyear)

raw_with_2025 <- raw_with_2025%>%
  dplyr::select(-c(386:393))

# Convert to pdata.frame
pdata <- pdata.frame(raw_with_2025, index = c("vid", "vyear"))

# Lag columns 237 to 779 by 3 years
cols_to_lag <- 230:764  # Specify the column range

# Create lagged columns
pdata <- pdata %>%
  mutate(across(all_of(cols_to_lag), ~ lag(., n = 3), .names = "lag3_{col}"))%>%
  dplyr::select(-all_of(cols_to_lag))

# Return to data frame

lag_3_2025 <- as.data.frame(pdata) %>%
  filter(vyear %in% c(1998, 2002, 2005, 2009, 2013, 2017, 2021, 2025)) %>%
  mutate(across(c(vafd, vlinke_pds), as.numeric))

# Build the function for automated model selection 

run_models_and_select_best <- function(x_train, y_train, x_test, y_test, lambda_type = "lambda.min",alpha_values = seq(0.1, 0.9, by = 0.1)) {
  
  # Helper function to calculate R^2
  calculate_r2 <- function(model, x_train, y_train, x_test, y_test, lambda_type) {
    best_lambda <- model[[lambda_type]]
    
    # Predictions
    y_train_pred <- predict(model, s = best_lambda, newx = x_train)
    y_test_pred <- predict(model, s = best_lambda, newx = x_test)
    
    # R^2 calculations
    ss_res_train <- sum((y_train - y_train_pred)^2)
    ss_tot_train <- sum((y_train - mean(y_train))^2)
    r2_train <- 1 - (ss_res_train / ss_tot_train)
    
    ss_res_test <- sum((y_test - y_test_pred)^2)
    ss_tot_test <- sum((y_test - mean(y_test))^2)
    r2_test <- 1 - (ss_res_test / ss_tot_test)
    
    return(list(
      r2_train = r2_train,
      r2_test = r2_test,
      predictions = y_test_pred
    ))
  }
  
  # Fit Lasso (alpha = 1)
  lasso <- cv.glmnet(x_train, y_train, alpha = 1, nfolds = 10)
  lasso_r2 <- calculate_r2(lasso, x_train, y_train, x_test, y_test, lambda_type)
  
  # Fit Ridge (alpha = 0)
  ridge <- cv.glmnet(x_train, y_train, alpha = 0, nfolds = 10)
  ridge_r2 <- calculate_r2(ridge, x_train, y_train, x_test, y_test, lambda_type)
  
  # Fit ElasticNet for each alpha value
  elasticnet_results <- list()
  for (alpha in alpha_values) {
    elasticnet <- cv.glmnet(x_train, y_train, alpha = alpha, nfolds = 10)
    elasticnet_r2 <- calculate_r2(elasticnet, x_train, y_train, x_test, y_test, lambda_type)
    elasticnet_results[[paste0("elasticnet_alpha_", alpha)]] <- list(model = elasticnet, r2 = elasticnet_r2, alpha = alpha)
  }
  
  # Combine all results
  models <- list(
    lasso = list(model = lasso, r2 = lasso_r2),
    ridge = list(model = ridge, r2 = ridge_r2)
  )
  models <- c(models, elasticnet_results)
  
  # Find the best model by test R^2
  best_model_name <- names(which.max(sapply(models, function(x) x$r2$r2_test)))
  best_model <- models[[best_model_name]]
  
  # Create a dataframe with predictions and actual values
  predictions_df <- data.frame(
    actual = y_test,
    predicted = as.vector(best_model$r2$predictions)
  )
  
  # Return results
  return(list(
    best_model_name = best_model_name,
    best_model_r2 = best_model$r2,
    best_model = best_model$model,  
    predictions_df = predictions_df,
    best_model_alpha = ifelse("alpha" %in% names(best_model), best_model$alpha, NA)
  ))
}

#Prepare the data 
data_2025 <- lag_3_2025 %>%
  filter(vyear==2025)

#The training data
lag_3_train <- lag_3_2025 %>%
  filter(vyear != 2025) %>%
  filter(vyear %in% c(2005, 2009, 2013, 2017)) %>%
  mutate(
    populist_voteshare = rowSums(across(c(vlinke_pds, vafd), ~ as.numeric(replace_na(., 0)))))%>%
  dplyr::select(where(~ sum(is.na(.)) < 1))

#Identify columns in lag_3_train
train_columns <- colnames(lag_3_train)

#The test data
lag_3_test <- lag_3_2025 %>%
  filter(vyear!=2025)%>%
  filter(vyear==2021)%>%
  mutate(populist_voteshare = rowSums(across(c(vlinke_pds, vafd), ~ replace_na(., 0))))%>%
  dplyr::select(all_of(train_columns))%>%
  dplyr::select(where(~ sum(is.na(.)) < 1))

#Identify the full columns in the test data and remove any columns from training data 
#that are not full in the test data
test_columns <- colnames(lag_3_test)

lag_3_train <- lag_3_train %>%
  dplyr::select(all_of(test_columns))

#Prepare the covariate matrices and outcome vectors
x <- as.matrix(lag_3_train[,c(51:299,1:3)])
x <- apply(x, 2, as.numeric)  # Convert all columns to numeric
x_interactions <- model.matrix(~ .^2, data = as.data.frame(x))[, -1]
y <- lag_3_train$populist_voteshare

x_test <- as.matrix(lag_3_test[, c(51:299, 1:3)])
x_test <- apply(x_test, 2, as.numeric)  # Ensure numeric matrix
x_interactions_test <- model.matrix(~ .^2, data = as.data.frame(x_test))[,-1]
y_test <- lag_3_test$populist_voteshare

#Run the models and automatically select the best one.
results <- run_models_and_select_best(
  x_train = x_interactions,
  y_train = y,
  x_test = x_interactions_test,
  y_test = y_test,
  alpha_values = seq(0.1, 0.95, by = 0.05)  # Specify alpha values for ElasticNet
)

cat("Best Model:", results$best_model_name, "\n")
cat("Best Alpha (if ElasticNet):", results$best_model_alpha, "\n")
cat("Training R^2:", results$best_model_r2$r2_train, "\n")
cat("Test R^2:", results$best_model_r2$r2_test, "\n")

predictions_base <- results$predictions_df
difference = predictions_base$predicted-predictions_base$actual
predictions_base$difference = difference
mse = difference^2
predictions_base$mse = mse

id = lag_3_test[,c("vid","populist_voteshare")]
colnames(id)[2] <- "actual"

predictions_base = merge(predictions_base,id,by="actual")
mean(predictions_base$mse)

# Best model object
best_model <- results$best_model

#Extract the best lambda
best_lambda <- results$best_model$lambda.min

# Extract the coefficients for the best lambda
best_coefs <- coef(best_model, s = best_lambda)

# Get variable names with non-zero coefficients
included_vars <- rownames(best_coefs)[which(best_coefs != 0)]

# View the included variables
cat("Variables included in the best model:\n", included_vars)

write.csv(predictions_base,"/Users/tracemiller/Documents/bocconi courses/foundation/assignment group/predictions_lag3.csv")
