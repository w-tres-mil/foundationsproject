### First attempts at map generation ----
gc()
rm(list=ls())

# Loading required packages ----

#install.packages("raster")
#install.packages("sp")
#install.packages("sf")
#install.packages("git2r")

library(raster)
library(httr)
library(sp)
library(sf)
library(ggplot2)
library(readxl)
library(git2r)


# URL of the .xlsx file
url <- "https://github.com/w-tres-mil/foundationsproject/raw/refs/heads/main/Model%20Prediction.xlsx"

# Download the file into a temporary file
temp_file <- tempfile(fileext = ".xlsx")
GET(url, write_disk(temp_file, overwrite = TRUE))

# Read the .xlsx file
#CHANGE SHEET NAME TO MAKE MAP FOR DIFFERENT LAG AND DUMMY COMBINATIONS
data <- read_xlsx(temp_file,sheet="lag1")

# URL of the repository
repo_url <- "https://github.com/awiedem/german_election_data.git"

# Directory to clone into
local_dir <- "countyshapefiles"

# Clone the repository
#clone(repo_url, local_dir)

# Print the cloned directory contents
list.files(local_dir)

shapefile_dir <- file.path(local_dir, "data/shapefiles/2021/vg250_ebenen_0101")

list.files(shapefile_dir)

# Loading the shapefile ----
st_layers(dsn = shapefile_dir)
germany <- st_read(dsn = shapefile_dir, layer = "VG250_KRS")

#Loading and merging the Numeric Data ----
colnames(data)[5] = "ARS"
data$difference=as.numeric(data$difference)
data$actual=as.numeric(data$actual)
data$predicted=as.numeric(data$predicted)

germany <- merge(germany, data, by = "ARS",all.x=TRUE)
germany_states <- st_read(dsn = shapefile_dir, layer = "VG250_LAN")

library(wesanderson)

# Define colors from the Darjeeling palette
darjeeling_colors <- wes_palette("Darjeeling1", n = 3)

# Plot the map with Darjeeling colors
ggplot() +
        geom_sf(data = germany, aes(fill = difference)) +
        geom_sf(data = germany_states, color = "black", fill = NA, size = 2.5, alpha = 1) +
        scale_fill_gradientn(colors = darjeeling_colors, name = "Prediction\nError\nw/ Dummy") + # Use Darjeeling colors
  theme(
    axis.title = element_blank(), # Remove axis titles
    axis.text = element_blank(),  # Remove axis text
    axis.ticks = element_blank(), # Remove axis ticks
    panel.grid = element_blank(), # Remove grid lines
    panel.background = element_blank() # Optional: remove panel background
  )
