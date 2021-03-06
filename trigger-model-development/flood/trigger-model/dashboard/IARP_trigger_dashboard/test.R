library(shiny)
library(janitor)
library(tidyverse)
library(lubridate)
library(plotly)
library(shinydashboard)
library(sf)
library(leaflet)
library(readr)

selected_pcode <- "020104"
selected_station <- "G1045"
selected_lowdate <- "2000-07-19"
selected_highdate <- "2018-04-05"
rainfall_threshold <- 2
glofas_threshold <- 864


rollmax(glofas$dis, k = 21)
#[1]  0.13677590  0.12419375  0.22781866  0.17661827  0.51935576  0.08137071 -0.29009330 -0.43751774
rollapply(df1$Value, width = 3, FUN = mean)
#[1]  0

glofas_variable='dis_7'
glofas_variable2='dis'

  
  

plot_ly(glofas) %>%
  add_lines(x=~date, y=as.formula(paste0('~', glofas_variable)), line=list(color="rgb(98, 211, 234)"),legendgroup = 'group1', name='rainfaall') %>%
  add_lines(x=~date, y=as.formula(paste0('~', glofas_variable2)), line=list(color="rgb(116, 169, 207)"),legendgroup = 'group1', name='Glofas Discharge') %>%
  add_segments(x=~min(date), xend=~max(date), y = glofas_threshold, yend=glofas_threshold, line=list(color="black"),legendgroup = 'group1', name='selected Threshold') %>%
  add_segments(x=date ,xend=date, y=0, yend=1500, name = 'Impact event',line=list(color="rgb(255, 153, 0)",width = 4),legendgroup = 'group1', name='reported impact') %>%
  add_segments(x=~min(date), xend=~max(date), y = rp_glofas$q10, yend=rp_glofas$q10, name = 'q10', line=list(color="rgb(253, 130, 155)", width = 2,dash = "dot"),legendgroup = 'group1', name='Q10') %>%
  add_segments(x=~min(date), xend=~max(date), y = rp_glofas$q50, yend=rp_glofas$q50, name = 'q50', line=list(color="rgb(205, 12, 24)",width = 2, dash = "dash"),legendgroup = 'group1', name='Q50') %>%
  layout(yaxis=list(title=paste0("Station", glofas_variable)), showlegend=TRUE)


p2 <- ggplot(rainfall) +
  aes(x = date, y = rainfall, color = 'red') +
  geom_line()


p<-ggplot(glofas) +
  geom_line(x=~date, y=as.formula(paste0('~', glofas_variable)), line=list(color="rgb(98, 211, 234)"), name='rainfaall') %>%
  geom_line(x=~date, y=as.formula(paste0('~', glofas_variable2)), line=list(color="rgb(116, 169, 207)"), name='Glofas Discharge') %>%
  geom_hline(x=~min(date), xend=~max(date), y = glofas_threshold, yend=glofas_threshold, line=list(color="black"), name='selected Threshold') %>%
  geom_vline(x=date ,xend=date, y=0, yend=1500, name = 'Impact event',line=list(color="rgb(255, 153, 0)",width = 4), name='reported impact') %>%
  geom_hline(x=~min(date), xend=~max(date), y = rp_glofas$q10, yend=rp_glofas$q10, name = 'q10', line=list(color="rgb(253, 130, 155)", width = 2,dash = "dot"), name='Q10') %>%
  geom_hline(x=~min(date), xend=~max(date), y = rp_glofas$q50, yend=rp_glofas$q50, name = 'q50', line=list(color="rgb(205, 12, 24)",width = 2, dash = "dash"),name='Q50') %>%
  layout(yaxis=list(title=paste0("Station", glofas_variable)), showlegend=TRUE)


p<-ggplot(data=glofas,aes(x=date, y=dis)) +
  geom_line()+
  geom_line(data=glofas,aes(x=date, y=dis_7))+
  geom_vline(xintercept=as.Date(impact_df$date)[[1]])+#(x=date, y=1200))+
  geom_vline(xintercept=as.Date(impact_df$date)[[2]])#(x=date, y=1200))+
  #geom_line(data=glofas,aes(x=date, y=dis_7))
fig <- ggplotly(p)
fig

#st_write(obj=ethiopia_admin3, dsn="shapes/eth_adminboundaries_3.shp")

setwd(dirname(rstudioapi::getSourceEditorContext()$path))
#setwd('dashboard/ethiopia_shiny_app')

source('r_resources/plot_functions.R')
source('r_resources/predict_functions.R')


rp_glofas <-rp_glofas_station %>%  filter(station == selected_station)

glofas <-glofas_raw %>%
    filter(station == selected_station) %>%
    filter(date >= selected_lowdate, date <= selected_highdate)

rainfall <- rainfall_raw[[1]]%>%    filter(      pcode == selected_pcode,
      date >= selected_lowdate,      date <= selected_highdate)








# Clean impact and keep relevant columns
df_impact_raw <- ethiopia_impact %>%
  clean_names() %>%
  mutate(date = dmy(date),
         pcode = str_pad(as.character(pcode), 6, "left", "0")) %>%
  dplyr::select(region, zone, wereda, pcode, date) %>%
  unique() %>%
  arrange(pcode, date)

impact_df <- df_impact_raw[[1]] %>%
    filter(pcode == selected_pcode,
           date >= selected_lowdate,
           date <= selected_highdate)



# Used to join against
all_days <- tibble(date = seq(min(df_impact_raw[[1]]$date, na.rm=T) - 60, max(df_impact_raw[[1]]$date, na.rm=T) + 60, by="days"))

# Clean GLOFAS mapping
glofas_mapping <- glofas_mapping %>%
  dplyr::select(-Z_NAME) %>%
  gather(station_i, station_name, -W_NAME) %>%
  dplyr::filter(!is.na(station_name)) %>%
  dplyr::select(-station_i) %>%
  left_join(ethiopia_impact %>% dplyr::select(Wereda, pcode) %>% unique(), by = c("W_NAME" = "Wereda")) %>%
  mutate(pcode = str_pad(as.character(pcode), 6, "left", "0")) %>%
  dplyr::filter(!is.na(pcode))


 

plot_rainfall_glofas(rainfall, glofas, impact_df, rainfall_threshold, glofas_threshold, has_glofas=TRUE,glofas_variable='dis')

predict_with_glofas_and_rainfall(all_days, rainfall, glofas, impact_df, rainfall_threshold, glofas_threshold, TRUE)

glofas %>%
  left_join(rainfall, by = "date") %>%
  left_join(impact_df %>% dplyr::select(date) %>% mutate(flood = TRUE), by = "date") %>%
  mutate(
    flood = replace_na(flood, FALSE),
    rainfall_exceeds_threshold = rainfall >= rainfall_threshold,
    glofas_exceeds_threshold = dis >= glofas_threshold,
    both_exceed_threshold = rainfall_exceeds_threshold & glofas_exceeds_threshold,
    flood_correct = flood & both_exceed_threshold,
    next_exceeds_threshold = lag(both_exceed_threshold),
    peak_start = !both_exceed_threshold & next_exceeds_threshold
  ) %>%
  summarise(
    floods = sum(flood),
    floods_correct = sum(flood_correct),
    floods_incorrect = floods - floods_correct,
    protocol_triggered = sum(peak_start, na.rm=T),
    triggered_in_vain = protocol_triggered - floods_correct,
    triggered_correct = floods_correct,
    detection_ratio = round(floods_correct / floods, 2),
    false_alarm_ratio = round(triggered_in_vain/protocol_triggered, 2)
  )




source('r_resources/plot_functions.R')
source('r_resources/predict_functions.R')

# swi <- read.csv("data/ethiopia_admin3_swi_all.csv", stringsAsFactors = F, colClasses = c("character", "character", "numeric", "numeric", "numeric"))
#ethiopia_impact <- read.csv("data/Eth_impact_data2.csv", stringsAsFactors = F, sep=";")

ethiopia_impact <- read.csv("data/Ethiopia_impact3.csv",stringsAsFactors = F, sep=",")


# rainfall_raw <- read_csv("data/ethiopia_admin3_rainfall.csv")  # CHIRPS, kept for legacy
eth_admin3 <- sf::read_sf("shapes/ETH_adm3_mapshaper.shp")
eth_admin3 <- st_transform(eth_admin3, crs = "+proj=longlat +datum=WGS84")

glofas_raw <- read_csv("data/GLOFAS_fill_allstation_.csv") %>% rename(date = time)
glofas_mapping <- read.csv("data/Eth_affected_area_stations2.csv", stringsAsFactors = F)
point_rainfall <- read_csv('data/Impact_Hazard_catalog.csv') %>% clean_names()

# Used to join against
all_days <- tibble(date = seq(min(df_impact_raw$date, na.rm=T) - 60, max(df_impact_raw$date, na.rm=T) + 60, by="days"))

# Clean impact and keep relevant columns
df_impact_raw <- ethiopia_impact %>%
  clean_names() %>%
  rename(region = i_region) %>%
  mutate(date = dmy(date),
         pcode = str_pad(as.character(pcode), 6, "left", "0")) %>%
  dplyr::select(region, zone, wereda, pcode, date) %>%
  unique() %>%
  arrange(pcode, date)

# Clean GLOFAS mapping
glofas_mapping <- glofas_mapping %>%
  dplyr::select(-Z_NAME) %>%
  gather(station_i, station_name, -W_NAME) %>%
  filter(!is.na(station_name)) %>%
  dplyr::select(-station_i) %>%
  left_join(ethiopia_impact %>% dplyr::select(Wereda, pcode) %>% unique(), by = c("W_NAME" = "Wereda")) %>%
  mutate(pcode = str_pad(as.character(pcode), 6, "left", "0")) %>%
  filter(!is.na(pcode))

# Clean glofas
glofas_raw <- glofas_raw %>%
  filter(
    date >= min(df_impact_raw$date, na.rm=T) - 60,
    date <= max(df_impact_raw$date, na.rm=T) + 60)

glofas_raw <- expand.grid(all_days$date, unique(glofas_raw$station)) %>%
  rename(date = Var1, station = Var2) %>%
  left_join(glofas_raw %>% dplyr::select(date, dis, station), by = c("date", "station")) %>% arrange(station, date) %>%
  arrange(station, date) %>%
  group_by(station) %>%
  fill(dis, .direction="down") %>%
  fill(dis, .direction="up") %>%
  ungroup()

rainfall_raw <- point_rainfall %>%
  left_join(df_impact_raw %>% dplyr::select(pcode, zone), by = "zone") %>%
  group_by(pcode, date) %>%
  summarise(rainfall = mean(rainfall, na.rm=T))

# Clean rainfall - CHIRPS, kept for legacy
# rainfall_raw <- rainfall_raw %>%
#   mutate(pcode = str_pad(pcode, 6, "left", 0)) %>%
#   filter(
#     date >= min(df_impact_raw$date, na.rm=T) - 60,
#     date <= max(df_impact_raw$date, na.rm=T) + 60)

# # SWI, kept for legacy
# swi_raw <- swi %>%
#   mutate(date = ymd(date))
#
# swi_raw <- swi_raw %>%
#   gather(depth, swi, -pcode, -date)

# Determine floods per Wereda for map
floods_per_wereda <- df_impact_raw %>%
  group_by(region, wereda, pcode) %>%
  summarise(
    n_floods = n()
  ) %>%
  arrange(-n_floods) %>%
  ungroup()

eth_admin3 <- eth_admin3 %>% left_join(floods_per_wereda %>% dplyr::select(pcode, n_floods), by = c("WOR_P_CODE" = "pcode")) %>%
  filter(!is.na(n_floods))

flood_palette <- colorNumeric(palette = "YlOrRd", domain = floods_per_wereda$n_floods)
glofas2<- glofas %>% mutate(flood=ifelse(dis >= 500,1,0)) %>%  mutate(cum_sep_len = c(NA,diff(accumulate(glofas2$flood, ~ ifelse(.x >= 0, .y, .x + .y)))))

glofas2<- glofas2 %>% mutate( Return_aux = ifelse( is.na(flood), 0, flood ), Cum_Sum = cumsum(Return_aux) )

test <- c(9, 3, 2, 2, 8, 5, 4, 9, 1)

#cumsum(c(FALSE, 
diff(accumulate(glofas2$flood, ~ ifelse(.x >= 0, .y, .x + .y)))# <= 0))


# Clean impact and keep relevant columns
df_impact_raw <- ethiopia_impact %>%
  clean_names() %>%
  rename(region = �..Region) %>%
  mutate(date = dmy(date),
         pcode = str_pad(as.character(pcode), 6, "left", "0")) %>%
  dplyr::select(region, zone, wereda, pcode, date) %>%
  unique() %>%
  arrange(pcode, date)
ethiopia_impact <- read.csv("data/Eth_impact_data2.csv", stringsAsFactors = F, sep=";")

library(readr)


 
ethiopia_impact <- read_delim("data/Ethiopia_impact3.csv", ",", escape_double = FALSE, trim_ws = TRUE)


# rainfall_raw <- read_csv("data/ethiopia_admin3_rainfall.csv")  # CHIRPS, kept for legacy
#eth_admin3 <- sf::read_sf("shapes/ETH_adm3_mapshaper.shp")  
eth_admin3 <- sf::read_sf("shapes/ETH_Admin3_2019.shp") 
eth_admin3 <- st_transform(eth_admin3, crs = "+proj=longlat +datum=WGS84")

glofas_raw <- read_csv("data/GLOFAS_fill_allstation_.csv") %>% rename(date = time)

glofas_mapping <- read.csv("data/Eth_affected_area_stations2.csv", stringsAsFactors = F)

point_rainfall <- read_csv('data/Impact_Hazard_catalog.csv') %>% clean_names()

rp_glofas_station <- read_csv('data/rp_glofas_station.csv') %>% clean_names()

