gc()
rm(list=ls())

library(haven)
library(glmnet)
library(plm)
library(httr)
library(dplyr)
library(tidyr)
library(glmnet)
library(ggplot2)

repo_owner <- readline(prompt = "Enter the repo owner: ")
repo_name <- readline(prompt = "Enter the repo name: ")
access_token <- readline(prompt = "Enter your GitHub personal access token: ")

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
  arrange(vid, vyear)  # Optional: Sort by `vid` and `vyear`

raw_with_2025 <- raw_with_2025%>%
  select(-c(386:393))

# Convert to pdata.frame
pdata <- pdata.frame(raw_with_2025, index = c("vid", "vyear"))

# Lag columns 237 to 779 by 3 years
cols_to_lag <- 230:764  # Specify the column range

# Create lagged columns
pdata <- pdata %>%
  mutate(across(all_of(cols_to_lag), ~ lag(., n = 1), .names = "lag1_{col}"))%>%
  select(-all_of(cols_to_lag))

# Return to data frame

lag_1_2025 <- as.data.frame(pdata) %>%
  filter(vyear %in% c(1998, 2002, 2005, 2009, 2013, 2017, 2021, 2025)) %>%
  mutate(across(c(vafd, vlinke_pds), as.numeric))


#Create a Eastern Germany Dummy
lag_1_2025 <- lag_1_2025 %>%
  mutate(vstate = as.numeric(vstate)) 

lag_1_2025 <- lag_1_2025%>%
  mutate(east_germany = ifelse(vstate >= 11, 1, 0)) %>% # Create binary variable
  mutate(vstate = as.factor(vstate))# Convert vid back to factor

#Prepare the data 
data_2025 <- lag_1_2025 %>%
  filter(vyear==2025)

#The training data
lag_2_train <- lag_1_2025 %>%
  filter(vyear != 2025) %>%
  filter(vyear %in% c(2005, 2009, 2013, 2017,2021)) %>%
  mutate(
    populist_voteshare = rowSums(across(c(vlinke_pds, vafd), ~ as.numeric(replace_na(., 0)))))%>%
  select(where(~ sum(is.na(.)) < 1))
# 
# lag_2_train = lag_2_train %>%
#   filter(vyear %in% 2021)


# #Prepare the covariate matrices and outcome vectors
# x <- as.matrix(lag_1_train[,c(51:313,1:3)])
# x <- apply(x, 2, as.numeric)  # Convert all columns to numeric
# x_interactions <- model.matrix(~ .^2, data = as.data.frame(x))[, -1]
# y <- lag_1_train$populist_voteshare
# 
# x_test <- as.matrix(lag_1_test[, c(51:313, 1:3)])
# x_test <- apply(x_test, 2, as.numeric)  # Ensure numeric matrix
# x_interactions_test <- model.matrix(~ .^2, data = as.data.frame(x_test))[,-1]
# y_test <- lag_1_test$populist_voteshare

set.seed(123)  # For reproducibility
lag_2_train$subset <- sample(1:5, nrow(lag_2_train), replace = TRUE)

# Initialize a list to store the results for each subset
subset_results <- list()

# Run Elastic Net on each subset
for (subset_id in 1:5) {
  # Split the data into current subset and the rest
  train_subset <- lag_2_train %>% filter(subset != subset_id)
  test_subset <- lag_2_train %>% filter(subset == subset_id)
  
  # Prepare the matrices
  x_train <- as.matrix(train_subset[,c(51:312,1:3)])
  x_train <- apply(x_train, 2, as.numeric)
  x_interactions <- model.matrix(~ .^2, data = as.data.frame(x_train))[, -1]
  y_train <- train_subset$populist_voteshare
  
  x_test <- as.matrix(test_subset[, c(51:312, 1:3)])
  x_test <- apply(x_test, 2, as.numeric)
  x_interactions_test <- model.matrix(~ .^2, data = as.data.frame(x_test))[,-1]
  y_test <- test_subset$populist_voteshare
  
  # Fit Elastic Net with alpha = 0.35
  elastic_net_model <- cv.glmnet(x_interactions, y_train, alpha = 0.35, nfolds = 5)
  
  # Get the best lambda and coefficients
  best_lambda <- elastic_net_model$lambda.min
  best_coefs <- coef(elastic_net_model, s = best_lambda)
  selected_vars <- rownames(best_coefs)[which(best_coefs != 0)]
  
  # Store the results
  subset_results[[subset_id]] <- list(
    subset_id = subset_id,
    coefficients = best_coefs,
    selected_vars = selected_vars
  )
}

# Get all unique variable names across subsets
all_vars <- unique(unlist(lapply(subset_results, function(result) result$selected_vars)))

# Create a consistent matrix
selected_vars_matrix <- sapply(subset_results, function(result) {
  as.numeric(all_vars %in% result$selected_vars)
})
rownames(selected_vars_matrix) <- all_vars
colnames(selected_vars_matrix) <- paste0("Subset_", 1:5)

# Calculate the frequency of selection for each variable
selected_vars_df <- as.data.frame(selected_vars_matrix)
selected_vars_df$Variable <- rownames(selected_vars_matrix)
selected_vars_df$Frequency <- rowSums(selected_vars_matrix)

# Sort variables by frequency of selection
selected_vars_df <- selected_vars_df %>%
  arrange(desc(Frequency))

# Transform the data for plotting
selected_vars_long <- selected_vars_df %>%
  pivot_longer(cols = starts_with("Subset"), names_to = "Subset", values_to = "Selected")

# Ensure the y-axis respects the new order of variables
selected_vars_long$Variable <- factor(selected_vars_long$Variable, levels = selected_vars_df$Variable)

# Update subset labels for the x-axis
selected_vars_long$Subset <- as.numeric(gsub("Subset_", "", selected_vars_long$Subset))

# Heatmap
# Ensure the y-axis respects the new order of variables (sorted by frequency)
selected_vars_long$Variable <- factor(selected_vars_long$Variable, levels = selected_vars_df$Variable)

# Update subset labels for the x-axis
selected_vars_long$Subset <- as.numeric(gsub("Subset_", "", selected_vars_long$Subset))

# Create the heatmap
ggplot(selected_vars_long, aes(x = Subset, y = Variable, fill = as.factor(Selected))) +
  geom_tile() +
  scale_fill_manual(
    values = c("0" = "white", "1" = "blue"), 
    labels = c("Zero", "Nonzero"), 
    name = "Estimate"
  ) +
  labs(
    title = "Variable Stability",
    x = "Sample Fold",
    y = "Covariate Selected"
  ) +
  theme_minimal() +
  theme(
    axis.text.y = element_blank(),  # Hide variable names on the y-axis
    axis.ticks.y = element_blank(),  # Remove y-axis ticks
    axis.text.x = element_text(size = 10),  # Adjust x-axis text size
    plot.title = element_text(hjust = 0.5),  # Center the title
    legend.position = "right",  # Place the legend on the right
    legend.title = element_text(size = 10),  # Adjust legend title size
    legend.text = element_text(size = 9)    # Adjust legend text size
  )

# Bar Plot
frequency_distribution <- selected_vars_df %>%
  group_by(Frequency) %>%
  summarise(Number_of_Variables = n())
ggplot(frequency_distribution, aes(x = Frequency, y = Number_of_Variables)) +
  geom_bar(stat = "identity", fill = "blue") +
  labs(
    title = "Distribution of Variable Selection Across Models",
    x = "Number of Models in Which the Variable is Selected",
    y = "Number of Variables"
  ) +
  theme_minimal()


# Install and load required libraries
if (!requireNamespace("writexl", quietly = TRUE)) {
  install.packages("writexl")
}
library(writexl)
library(dplyr)
library(tidyr)
# Create a data frame to store results
all_vars <- unique(unlist(lapply(subset_results, function(result) result$selected_vars)))  # Get all unique variables
n_subsets <- length(subset_results)  # Number of subsets

# Create an empty results data frame
results_df <- data.frame(
  var_name = all_vars,  # Variable names (including interaction terms)
  n_models_selected = numeric(length(all_vars)),  # Number of models in which each variable is selected
  matrix(NA, nrow = length(all_vars), ncol = n_subsets,  # Placeholder for coefficients in each subset
         dimnames = list(NULL, paste0("coeff_subs_", 1:n_subsets)))
)

# Fill the results data frame
for (subset_id in 1:n_subsets) {
  selected_vars <- subset_results[[subset_id]]$selected_vars  # Variables selected in this subset
  coefficients <- subset_results[[subset_id]]$coefficients  # Coefficients in this subset
  
  # Iterate over variables to populate coefficients
  for (var in all_vars) {
    if (var %in% selected_vars) {
      coef_value <- coefficients[var, 1]  # Extract the coefficient value
      results_df[results_df$var_name == var, paste0("coeff_subs_", subset_id)] <- coef_value
    }
  }
}

# Calculate the number of models in which each variable is selected
results_df$n_models_selected <- rowSums(!is.na(results_df[, paste0("coeff_subs_", 1:n_subsets)]))

# Calculate the average coefficient across subsets
results_df$avg_coefficient <- rowMeans(results_df[, paste0("coeff_subs_", 1:n_subsets)], na.rm = TRUE)

# Calculate the standard deviation of coefficients across subsets
results_df$std_dev_coefficient <- apply(results_df[, paste0("coeff_subs_", 1:n_subsets)], 1, sd, na.rm = TRUE)

# Sort the data frame by number of models selected and then by average coefficient
results_df <- results_df %>%
  arrange(desc(n_models_selected), desc(avg_coefficient))

# Export to Excel
output_file <- "/Users/tracemiller/Documents/bocconi courses/foundation/assignment group/variable_selection_results_with_interactions.xlsx"  # Change to your desired path
write_xlsx(results_df, output_file)

cat("Excel file created at:", output_file, "\n")

