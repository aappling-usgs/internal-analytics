gsMap_fx <- function(sf.points, high_col, low_col){
  gsMap <- ggplot(sf.points,aes(x=long, y=lat, fill=Sessions)) + 
    coord_equal() +
    geom_polygon(colour="grey75", size=0.1,
                 aes(group=group)) +
    guides(fill=guide_legend(title.position="top")) +
    theme_minimal() +
    theme(panel.grid = element_blank(),
          axis.text = element_blank(),
          axis.title = element_blank(),
          legend.title.align=0.5,
          plot.margin=unit(c(0,0,0,0), "cm"),
          legend.text=element_text(size=9),
          legend.title = element_text(size = 9),
          legend.key.width = unit(0.4, "cm"),
          legend.key.height = unit(0.4, "cm")) +
    scale_fill_gradient(na.value = 'transparent',labels = comma,
                        low = low_col, high = high_col)
  return(gsMap)
  
}

visualize.viz_geo_portfolio <- function(viz){
  library(dplyr)
  library(maptools)
  library(maps)
  library(sp)
  library(scales)
  library(ggplot2)
  
  viz.data <- readDepends(viz)[["viz_data"]]
  height = viz[["height"]]
  width = viz[["width"]]
  high_col = viz[["high_col"]]
  low_col = viz[["low_col"]]

  states.out <- get_map_stuff()

  region_summary <- data.frame(table(viz.data$region), stringsAsFactors = FALSE)  %>%
    arrange(desc(Freq)) %>%
    mutate(region = tolower(Var1)) %>%
    select(-Var1) %>%
    right_join(data.frame(region = names(states.out), stringsAsFactors = FALSE), by="region") 
  
  sf.points <- fortify(states.out, region="region")
  
  if(nrow(region_summary) <= 0){
    region_summary <- data.frame(Freq = 0,
                                 region = "district of columbia",
                                 stringsAsFactors = FALSE)
  }
  
  sf.points <- left_join(sf.points, region_summary, by=c("id"="region")) %>%
    rename(Sessions = Freq)
  
  gsMap <- gsMap_fx(sf.points, high_col, low_col)
  
  ggsave(gsMap, filename = viz[["location"]], height = height, width = width)
  
}

visualize.viz_geo_apps <- function(viz=as.viz("viz_geo_apps")){
  library(dplyr)
  library(maptools)
  library(maps)
  library(sp)
  library(ggplot2)
  library(scales)
  
  viz.data <- readDepends(viz)[["viz_data"]]
  height = viz[["height"]]
  width = viz[["width"]]
  high_col = viz[["high_col"]]
  low_col = viz[["low_col"]]
  
  x <- data.frame(id = character(),
                  loc = character(),
                  type = character(),
                  stringsAsFactors = FALSE)
  
  plot_type <- viz[["plottype"]]
  
  states.out <- get_map_stuff()
  
  for(i in unique(viz.data$viewID)){
    
    sub_data <- filter(viz.data, viewID == i)
    
    region_summary <- data.frame(table(sub_data$region), stringsAsFactors = FALSE)  %>%
      arrange(desc(Freq)) %>%
      mutate(region = tolower(Var1)) %>%
      select(-Var1) 
    
    sf.points <- fortify(states.out, region="region")
    
    location <- paste0("cache/visualize/",i,"_",plot_type,".png")
    
    if(nrow(region_summary) <= 0){
      region_summary <- data.frame(Freq = 0,
                                   region = "district of columbia",
                                   stringsAsFactors = FALSE)
    } 
    
    sf.points <- left_join(sf.points, region_summary, by=c("id"="region"))%>%
      rename(Sessions = Freq)
    
    gsMap <- gsMap_fx(sf.points, high_col, low_col)
    
    ggsave(gsMap, filename = location, height = height, width = width)
    
    x <- bind_rows(x, data.frame(id = i,
                                 loc = location,
                                 type = plot_type,
                                 stringsAsFactors = FALSE))      
    
  }
  
  write.csv(x, file=viz[["location"]], row.names = FALSE)
  
}


get_map_stuff <- function(){
  library(maptools)
  library(maps)
  library(sp)
  
  proj.string <- "+proj=laea +lat_0=45 +lon_0=-100 +x_0=0 +y_0=0 +a=6370997 +b=6370997 +units=m +no_defs"
  
  to_sp <- function(...){
    map <- maps::map(..., fill=TRUE, plot = FALSE)
    IDs <- sapply(strsplit(map$names, ":"), function(x) x[1])
    map.sp <- map2SpatialPolygons(map, IDs=IDs, proj4string=CRS("+proj=longlat +datum=WGS84"))
    map.sp.t <- spTransform(map.sp, CRS(proj.string))
    return(map.sp.t)
  }
  
  shift_sp <- function(sp, scale, shift, rotate = 0, ref=sp, proj.string=NULL, row.names=NULL){
    orig.cent <- rgeos::gCentroid(ref, byid=TRUE)@coords
    scale <- max(apply(bbox(ref), 1, diff)) * scale
    obj <- elide(sp, rotate=rotate, center=orig.cent, bb = bbox(ref))
    ref <- elide(ref, rotate=rotate, center=orig.cent, bb = bbox(ref))
    obj <- elide(obj, scale=scale, center=orig.cent, bb = bbox(ref))
    ref <- elide(ref, scale=scale, center=orig.cent, bb = bbox(ref))
    new.cent <- rgeos::gCentroid(ref, byid=TRUE)@coords
    obj <- elide(obj, shift=shift*10000+c(orig.cent-new.cent))
    if (is.null(proj.string)){
      proj4string(obj) <- proj4string(sp)
    } else {
      proj4string(obj) <- proj.string
    }
    
    if (!is.null(row.names)){
      row.names(obj) <- row.names
    }
    return(obj)
  }
  
  
  conus <- to_sp('state')
  
  # thanks to Bob Rudis (hrbrmstr):
  # https://github.com/hrbrmstr/rd3albers
  
  # -- if moving any more states, do it here: --
  move_variables <- list(
    alaska = list(scale=0.33, shift = c(80,-450), rotate=-50),
    hawaii = list(scale=1, shift=c(520, -110), rotate=-35),
    `district of columbia` = list(scale = 8, shift = c(30,-1), rotate=0)
    # PR = list(scale=2.5, shift = c(-140, 90), rotate=20)
  )
  
  stuff_to_move <- list(
    alaska = to_sp("world", "USA:alaska"),
    hawaii = to_sp("world", "USA:hawaii"),
    `district of columbia` = conus[names(conus) == 'district of columbia', ]
    # PR = to_sp("world", "Puerto Rico")
  )
  
  states.out <- conus[names(conus) != 'district of columbia', ]
  
  wgs84 <- "+init=epsg:4326"
  
  
  for(i in names(move_variables)){
    shifted <- do.call(shift_sp, c(sp = stuff_to_move[[i]], 
                                   move_variables[[i]],  
                                   proj.string = proj4string(conus),
                                   row.names = i))
    states.out <- rbind(shifted, states.out, makeUniqueIDs = TRUE)
    
  }
  
  return(states.out)
}
