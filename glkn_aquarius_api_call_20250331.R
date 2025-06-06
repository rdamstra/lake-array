---
  title: "Aquarius Data Download"
output: html_notebook
---
  
#Download and clean GLKN data from Aquarius.
#Updates 25 July 2023 by Hallie Arno. 

#```{r}
library(tidyverse)
library(lubridate)
library(jsonlite)
library(httr)
library(zoo)
library(magrittr)
library(data.table)

# Load the wrapper and authenticate with the app server path updated by rdamstra 20230331
source("M:/Monitoring/Water_Quality/Inland_Lakes/Data/Array_Data/API_data_calls_R/timeseries_client.R")
#```

#upload data 
#Function to download data from API - returns dataframe with date, one column for each depth, populated with temperature values in degrees C. 
#```{r}

#Function inputs are locations (as a list), start time, and end time
getdata <- function(loc_list, starttime, endtime){
  
  ###Make a note about where timeseries_client.R
  
  timeseries$connect("https://aquarius.nps.gov", "aqreadonly", "aqreadonly")
  
  # Get data specified in the code block above
  temps = timeseries$getTimeSeriesData(loc_list,
                                       queryFrom = starttime, queryTo = endtime)
  tempsdata <- data.frame(temps[4]) #temps$Points is the same as temps[4]
  
  #"Escape" in case df returns empty
  if(length(tempsdata) > 1){
    # Extract columns with water temperature data
    #These contain "NumericValue" in column name
    data_to_return <- tempsdata[grepl("NumericValue",colnames(tempsdata))]
    
    # Rename columns to depth, this is metadata returned from aq in a different df
    colnames(data_to_return) <- temps$TimeSeries$Label #same as temps[1]
    
    # Add date and time column, from df that numeric values were extracted from
    data_to_return$datetime <- tempsdata$Points.Timestamp ###Combine with next step
    
    data_to_return$datetime <- lubridate::as_datetime(data_to_return$datetime)
    
    # Return the df with datetime and temp values
    data_to_return <- data.frame(data_to_return) ###Try removing
    
    
    
    return(data_to_return)
    
  }
  # Not sure is this is necessary
  timeseries$disconnect()
  
}
#```



#Get list of strings to run through getdata functionn. 
#```{r}
sites <- list("VOYA_21", "VOYA_22", "VOYA_05", "PIRO_04", "PIRO_01", "SLBE_05", "SLBE_01", "ISRO_03")

#Start time and end time for the function "getdata"
starttime <- "2010-01-01"
endtime <- "2024-11-01"

#The order in depth_list corresponds with depths available in sites.
#If a site is changed or removed, 
depth_list <- list(
  c(0, 1.5, 2:28), 
  c(0, 1.0, 1.2, 2:23), 
  c(0, 1.5, 2:6), 
  c(1.5, 2:9), 
  c(0, 1, 1.5, 2:18), 
  c(0, 1.5, 2:8), 
  c(0, 1.5, 2:13), 
  c(0, 1.5:10.5, 2:11))


#Makes list of strings
strlist <- lapply(1:length(sites), function(i) {
  paste0("Water Temp.", trimws(format(round(depth_list[[i]], digits = 1))), "m_temp_array@GLKN_", sites[[i]])
}) %>% 
  unlist(.)

strlist
#```

#```{r}
data_all <- lapply(strlist, function(i){
  dt <- data.table(getdata(i, starttime, endtime)) #Uses function above to call data from Aquarius
  
  if(length(dt) > 1){ #To avoid errors from empty dataframes
    colnames(dt) <- c("temp", "date") #Rename columns
    dt[,SiteInfo := i]
    
    #See progress:
    print(i)   
    return(dt)
  }
})  %>%
  rbindlist(., use.names=F, fill=F) #Binds all outputs together 

data_all
#```
#```{r}
data_all <- data_all %>% 
  mutate(Site = sub('.*@GLKN_', '', SiteInfo)) %>% 
  mutate(Depth = sub('.*Temp.', '', SiteInfo)) %>% 
  mutate(Depth = as.numeric(sub('m_temp.*', '', Depth)))
data_all
#```

