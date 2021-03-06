library(dplyr)
library(ggplot2)
library(tidyr)
library(purrr)
library(stringr)
library(tmap)
library(maps)
library(httr)
library(sf)
library(ncdf4)
library(httr)
library(zoo)
library(grid)
library(ggpubr)
library(purrr)
library(nngeo)
#---------------------- setting -------------------------------
Country="uganda"
setwd(dirname(rstudioapi::getSourceEditorContext()$path))

source("Geo_settings.R")
setwd('../')
settings <- country_settings
url<- parse_url(url_geonode)

#----------------------------function defination -------------

prep_glofas_data <- function(){
  # Read glofas files
  
  
  # Read glofas files
  glofas_files <- list.files(paste0(getwd(),'/input/Glofas/station_csv'),pattern = '.csv')
  glofas_stations <- str_match(glofas_files, '^(?:[^_]*_){3}([^.]*)')[,2]
  
  #glofas_files1 <- str_match(glofas_files, '^(?:[^_]*_){2}([^.]*)')[,1]
  #glofas_stations <-c('G1904','G1905','G1906')
  
  glofas_data <- map2_dfr(glofas_files, glofas_stations, function(filename,glofas_station) {
    suppressMessages(
      read.csv(file.path(paste0(getwd(),'/input/Glofas/station_csv') , filename))  %>%
        mutate(time=as.Date(time),year=format(as.Date(time, format="%d/%m/%Y"),"%Y"),station2 = glofas_station,dis_3day=dis_3,dis_7day=dis_7) %>%
        select(time,year,station,dis,dis_3day,dis_7day))})
  
  
  glofas_data <- glofas_data %>%
    select(time,year,station,dis,dis_3day,dis_7day)%>%
    rename(date = time)  
  
  
  
  return(glofas_data)
}

fill_glofas_data <- function(glofas_data){
  
  glofas_filled <- tibble(date = seq(min(glofas_data$date), max(glofas_data$date), by = "1 day"))
  glofas_filled <- merge(glofas_filled, tibble(station = unique(glofas_data$station)))
  
  glofas_filled <- glofas_filled %>%
    left_join(glofas_data, by = c("station", "date")) %>%
    arrange(station, date) %>%
    mutate(dis = na.locf(dis),dis_3day = na.locf(dis_3day),dis_7day = na.locf(dis_7day))
  glofas_filled<-glofas_filled %>% distinct(date,station,.keep_all = TRUE)
  return(glofas_filled)
}

make_zoomed_in_plots <- function(impact_county,impact,hazard,t_delta=30,pdf_name){
  pdf(pdf_name, width=11, height=8.5)
  
  impact <- impact %>% mutate(Date_= as.Date(as.character(Date),format="%d/%m/%Y"))
  
  for (i in 1:nrow(impact)) {
    # Get data from row
    flood_date <- impact[i, ]$Date_
    district <- as.character(impact[i, ]$name)
    #certainty <- impact_data[i, ]$Certainty
    Deaths <- impact[i, ]$Deaths
    Affected <- impact[i, ]$Affected
    
    # Create description for top of plot
    description <- paste0(
      "Date: ", flood_date, " \t",
      "District: ", district, "\n",
      "Deaths: ", Deaths, " \t",
      "People Affected: ", Affected, "\t"
    )
    
    # Filter rainfall data 
    date_from <- flood_date - t_delta
    date_to <- flood_date + t_delta
    hazard_sub <- hazard %>% filter(Date > date_from, Date < date_to, Lead_time %in% c("t0", "t_3days", "t_7days")) #%>%mutate(flood = ifelse(date == flood_date, TRUE, NA))
    hazard_sub$dis <- hazard_sub$dis %>% as.numeric
    
    # Filter if less than 30 rows because event is more in the future than rainfall data
    if (nrow(hazard_sub) < t_delta+1) {
      plot(c(0, 1), c(0, 1), ann = F, bty = 'n', type = 'n', xaxt = 'n', yaxt = 'n')
      text(x = 0.5, y = 0.5, paste0(description, "\n", "no hazard data available"), 
           cex = 3, col = "black")
      next()
    }
    
    # Filter if no weather data available
    if (nrow(hazard_sub %>% filter(!is.na(dis))) == 0) {
      plot(c(0, 1), c(0, 1), ann = F, bty = 'n', type = 'n', xaxt = 'n', yaxt = 'n')
      text(x = 0.5, y = 0.5, paste0(description, "\n", "no hazard data available"), 
           cex = 3, col = "black")
      next()
    }
    
    # Make plot facetwrapped for each variable
    # options(repr.plot.width = 6, repr.plot.height = 2)
    p1 <- hazard_sub %>% ggplot(aes(x = Date,y=dis)) + geom_line(aes(colour = Lead_time)) +
      geom_vline(xintercept = flood_date, linetype="dotted",  color = "red", size=1.5) +
      #geom_text(x=flood_date, y=.75*max(hazard_sub$dis), label=paste()"Scatter plot")
      #geom_point(aes(y = value * flood), color = "red") + facet_wrap(~Lead_time) +
      theme(axis.text.x = element_text(angle = 90, hjust = 1),
            plot.title = element_text(hjust = 0.5, size = 10)) +
      ggtitle(description) +theme(legend.position = c(0.06, 0.75))
    
    p<-ggarrange(p1,impact_county + rremove("x.text"),widths = c(2, 0.6),
                 labels = c("", "Location"),
                 ncol = 2, nrow = 1)
    print(p)
  }
  
  dev.off() 
}


#-------------------------read boundary shape files and stations----------------
for (elm in  names(eval(parse(text=paste("settings$",Country,sep=""))))){
  url$query <- list(service = "WFS",version = "2.0.0",request = "GetFeature",
                    typename = eval(parse(text=paste("settings$",Country,"$",elm,sep=""))),
                    outputFormat = "application/json")
  request <- build_url(url)
  data_read <- st_read(request)
  assign(elm,data_read)
} 

for (elm in  names(settings$general_basin)){
  url$query <- list(service = "WFS",
                    version = "2.0.0",
                    request = "GetFeature",
                    typename = eval(parse(text=paste("settings$general_basin","$",elm,sep=""))),
                    outputFormat = "application/json")
  request <- build_url(url)
  data_read <- st_read(request)
  assign(elm,data_read)
} # download Geo Data 

for (elm in  names(settings$general_geo)){
  url$query <- list(service = "WFS",
                    version = "2.0.0",
                    request = "GetFeature",
                    typename = eval(parse(text=paste("settings$general_geo","$",elm,sep=""))),
                    outputFormat = "application/json")
  request <- build_url(url)
  data_read <- st_read(request)
  assign(elm,data_read)
} # download Geo Data 

# download geo data
# check validity of shape files downloaded from geonode server 

admin1 <- admin1 %>%filter(st_is_valid(geometry))
impact_data <- impact_data %>%filter(st_is_valid(geometry))
admin2 <- admin2 %>%filter(st_is_valid(geometry))

write.csv(impact_data, "c:/Users/BOttow/Documents/IBF-system/trigger-model-development/flood/trigger-model/dashboard/uganda_shiny_app/data/Eth_impact_data.csv", row.names = F)
writeOGR(admin2, )

#admin3 <- admin3 %>%filter(st_is_valid(geometry))
#admin3 <- st_transform(admin3, st_crs(crs1))
impact_data1_1 <- impact_data %>%
  mutate(date = as.Date(Date, format="%Y/%m/%d"),flood = 1) #%>% dplyr::select(-Region)

#---------------------- aggregate IMpact data for admin 2 admin 1 -------------------------------
# to do define impact columns in setting file in Ethiopian Case Crop.Damages, Lost.Cattle,Affected 
impact_data_ts <- impact_data %>% mutate(Affected=as.numeric(PplAffc),
                                         Deaths=as.numeric(Deaths),
                                         flood=as.numeric(flood))#%>% st_set_geometry(NULL)

impact_data_district <- impact_data_ts %>% st_set_geometry(NULL) %>% group_by(name) %>%
  summarise(Affected = sum(Affected,na.rm=TRUE), Deaths = sum(Deaths,na.rm=TRUE), flood = sum(flood,na.rm=TRUE)) %>%
  ungroup()

impact_data_district <- impact_data_district %>%
  left_join(admin2, by="name")


impact_data_district <- impact_data_district %>% st_set_geometry(impact_data_district$geometry)

impact_data_district <- impact_data_district %>% filter(st_is_valid(geometry))
impact_data_district <- st_transform(impact_data_district, st_crs(4326))


#---------------------- Hydro/mettrological stations in affected regions -------------------------------
river_uga <- st_intersection(rivers, admin1) %>% filter(UP_CELLS>1500) ##arrange(desc(UP_CELLS)) %>% dplyr::select(ARCID,geometry)
uga_glofas_st <- glofas_st %>% filter(CountryNam =='Uganda')%>% mutate(station=id) %>% select(station) 

# based on nearest glofas station with in 50km from the impacted district 
admin_centroid_pts <- impact_data_ts %>% mutate(cent_lon=map_dbl(geometry, ~st_centroid(.x)[[1]]), 
                                                cent_lat=map_dbl(geometry, ~st_centroid(.x)[[2]])) %>% 
  as.data.frame() %>% distinct(name, .keep_all = TRUE)

# convert to simple dataframe
admin_centroid_pts <- st_as_sf(admin_centroid_pts, coords = c("cent_lon","cent_lat"), crs=4326, remove = FALSE) %>%  select(name)
admin_centroid_pts <- st_transform(admin_centroid_pts, 4326)
uga_glofas_st <- st_transform(uga_glofas_st, 4326)


# find the first nearest neighbor rainfall station station for each centroid,  maximum 
glofas_stations_in_affected_areas <- st_join(admin_centroid_pts, uga_glofas_st, st_nn, k = 2, maxdist = 70000) %>% 
  st_set_geometry(NULL) %>% select(name, station) %>% filter(!is.na(station))
glofas_stations_in_affected_areas <- glofas_stations_in_affected_areas  %>% distinct(name, station, .keep_all = TRUE)

#NAM_stations_in_affected_areas<-st_join(admin_centroid_pts, NMA_stations, st_nn, k = 2,maxdist = 20000)%>% st_set_geometry(NULL)%>% select(County,station) %>% filter(station !='NA')
#NAM_stations_in_affected_areas<-NAM_stations_in_affected_areas  %>% distinct(Zone,station,.keep_all = TRUE)

#hyd_stations_in_affected_areas<-st_join(admin_centroid_pts, eth_hydro_st, st_nn, k = 2,maxdist = 30000)%>% st_set_geometry(NULL)%>% select(Zone,station) %>% filter(station !='NA')
#hyd_stations_in_affected_areas<-hyd_stations_in_affected_areas  %>% distinct(County,station,.keep_all = TRUE)

glofas_stations_in_affected_areas <- read.csv(paste0(getwd(),'/input/uga_affected_area_stations.csv'), stringsAsFactors = F)

filter_on_column <- function(data, column){
  data %>% filter(Impact_data == 1 & (! is.na(eval(parse(text=column))) & ! eval(parse(text=column)) == "")) %>% 
    select(name, station = !!column)
}
glofas_stations_in_affected_areas_filtered <- 
  bind_rows(filter_on_column(data = glofas_stations_in_affected_areas, column = "Glofas_st"),
          filter_on_column(data = glofas_stations_in_affected_areas, column = "Glofas_st2"),
          filter_on_column(data = glofas_stations_in_affected_areas, column = "Glofas_st3"),
          filter_on_column(data = glofas_stations_in_affected_areas, column = "Glofas_st4"))

#---------------------- vistualize stations and risk areas -------------------------------

tmap_mode(mode = "view")
tm_shape(impact_data_district) + tm_polygons(col = "flood", name='name',
                                           palette=c('#fef0d9','#fdbb84','#fc8d59','#b30000'),
                                           breaks=c(0,5,25,100,1000),colorNA=NULL,
                                           labels=c('< 5','5 - 25','25 - 100','100 - 1000'),
                                           title="No of Floods",
                                           border.col = "black",lwd = 0.5,lyt='dotted')+
  tm_shape(glofas_st) + tm_symbols(size=0.5,border.alpha = 0.25,col='#045a8d') +
  tm_shape(uga_glofas_st) + tm_symbols(size=0.5,border.alpha = 0.5,col='#74a9cf') +
  #tm_shape(Eth_affected_area_stations_ZONE) + tm_symbols(size=0.9,border.alpha = 0.25,col='#045a8d') +
  #tm_shape(NMA_stations) + tm_text("Gh_id",size=.5)+ 
  #tm_symbols(size=0.25,border.alpha = 0.25,col='#bdbdbd') +
  tm_shape(river_uga) + tm_lines(lwd=1,alpha = 0.5,col='#74a9cf') +
  tm_shape(admin2) + tm_borders(lwd = .5,col='#bdbdbd') + #
  tm_format("NLD")



#---------------------- read glofas data hazard ------------------------------- 

glofas_data <- prep_glofas_data() 
glofas_data <- glofas_data %>% filter (station %in% glofas_stations_in_affected_areas_filtered$station)

fill_glofas_data_<-fill_glofas_data(glofas_data)

make_glofas_district_matrix <- function(glofas_data,glofas_stations) {
  glofas_data <- glofas_data %>% 
    left_join(glofas_stations, by="station") %>% filter(name !='Na')  %>% # spread(station, dis_3day) %>%  mutate(district = toupper(Z_NAME)) %>%
    arrange(name, date)%>% rename(Date=date)  
  return(glofas_data)
}

glofas_district_matrix <- make_glofas_district_matrix(fill_glofas_data_,glofas_stations_in_affected_areas_filtered)

#rainfall_district_matrix<- make_rainfall_district_matrix(rainfall_df,NAM_stations_in_affected_zones) %>% rename(rain_station=Name)
#data_matrix<-rainfall_district_matrix %>% full_join(glofas_district_matrix %>% select(-year),by=c("Date","Zone"))


impact_data_df<- impact_data_ts %>% 
  st_set_geometry(NULL) %>% mutate(flood=1)%>%
  select("name","Deaths","Affected","Date","flood") 

Impact_hazard_catalog<- glofas_district_matrix  %>% 
  full_join(impact_data_df %>%mutate(Date=as.Date(Date,format="%d/%m/%Y")),by=c("Date","name"))

###### write Impact hazard catalog to file 
write.table(Impact_hazard_catalog, file = "dashboard/catalog_view_uganda/data/Impact_Hazard_catalog.csv", append = FALSE, quote = TRUE, sep = ";",
            eol = "\n", na = "NA", dec = ".", row.names = FALSE,
            col.names = TRUE, qmethod = c("escape", "double"),
            fileEncoding = "")


#### plot graps for EAP

for (zones in as.character(unique(impact_data_df$name)))
{
  Hazard_glofas <- glofas_district_matrix %>% filter(as.character(name) ==!!zones)# %>%   pull()
  impact <- impact_data_df %>% filter(as.character(name) ==!!zones) 
  
  for (st  in unique(Hazard_glofas$station)){
    print(st)
    print(zones)
    
    plot_data <- Hazard_glofas %>%
      filter(station == !!st) %>%
      select(-year) %>% 
      rename(t0=dis,t_3days=dis_3day, t_7days=dis_7day) %>% 
      gather('Lead_time','dis',-Date,-station,-name)
    
    impact_county <- ggplot() +   geom_sf(data = admin2) + 
      geom_sf(data = admin2 %>% filter(as.character(name) ==!!zones),col ='red',fill = 'red') +
      geom_sf(colour = "blue", size = 3,data=glofas_st %>% filter(glofas_st$ID %in% st)) +theme(  axis.text.x = element_blank(),
                                                                                                  axis.text.y = element_blank(),
                                                                                                  axis.ticks = element_blank())
    
    
    #p<- ggplot(plot_data, aes(Date,dis)) + geom_line(aes(colour = Lead_time))
    make_zoomed_in_plots(impact_county = impact_county, 
                         impact = impact,
                         hazard = plot_data,
                         t_delta = 100,
                         pdf_name=paste0(getwd(),"/output/uganda/",zones,st,"zoomed_in_per_flood.pdf"))
    
    #print(p)
    # p <- plot_data %>%  ggplot(aes(x = date, y = dis)) + geom_line() + geom_label(aes(y=dis, label=label)) +
    #ggtitle(station) + theme(plot.title = element_text(hjust = 0.5, size = 16))
    
  }
}








