options(repos = c(CRAN = "https://cloud.r-project.org"))

# install.packages('readr')
# install.packages('tidytext')
# install.packages('stringr')
# install.packages('shiny')
# install.packages('dplyr')
# install.packages("rvest")
# install.packages("httr")
# install.packages("bslib")

library(readr)
library(tidytext)
library(stringr)
library(shiny)
library(dplyr)
library(bslib)
library(stringr)
library(leaflet)
library(rvest)
library(httr)


#data import
tryCatch({
  mta_art <- read_csv("https://raw.githubusercontent.com/rfordatascience/tidytuesday/refs/heads/main/data/2025/2025-07-22/mta_art.csv")
  station_line <- read_csv("https://raw.githubusercontent.com/rfordatascience/tidytuesday/refs/heads/main/data/2025/2025-07-22/station_lines.csv")
}, error = function(e) {
  stop("Failed to load data. Please check internet connection and data sources.")
})



#duplication
duplicated_rows <- station_line[duplicated(station_line), ]

duplicated_station_line <- station_line %>%
  group_by(station_name, line) %>%
  filter(n() > 1)

duplicated_station_line <- duplicated_station_line %>%
  arrange(station_name, line)

print(duplicated_station_line)

clean_station_line <- station_line %>%
  distinct(station_name, line, .keep_all = TRUE)




stops <- read.csv("gtfs/stops.txt")

unique(clean_station_line$station_name)
unique(stops$stop_name)


#align the station name
stops_clean <- stops %>%
  mutate(stop_name_clean = str_to_lower(str_replace_all(stop_name, "[^A-Za-z0-9 ]", "")))

clean_station_line_clean <- clean_station_line %>%
  mutate(station_name_clean = str_to_lower(str_replace_all(station_name, "[^A-Za-z0-9 ]", "")))


stops_clean_dedup <- stops_clean %>%
  group_by(stop_name_clean) %>%
  slice(1) %>%
  ungroup()

station_with_coords <- clean_station_line_clean %>%
  inner_join(stops_clean_dedup, by = c("station_name_clean" = "stop_name_clean"))



shape_colors <- c(
  "1" = "#EE352E", "2" = "#EE352E", "3" = "#EE352E",  
  "4" = "#00933C", "5" = "#00933C", "6" = "#00933C",  
  "A" = "#0039A6", "C" = "#0039A6", "E" = "#0039A6",  
  "B" = "#FF6319", "D" = "#FF6319", "F" = "#FF6319", "M" = "#FF6319",  
  "G" = "#6CBE45", 
  "J" = "#996633", "Z" = "#996633", 
  "L" = "#A7A9AC", 
  "N" = "#FCCC0A", "Q" = "#FCCC0A", "R" = "#FCCC0A", "W" = "#FCCC0A",  
  "S" = "#808183"
)

shapes <- read_csv("gtfs/shapes.txt")

shapes_grouped <- shapes %>%
  arrange(shape_id, shape_pt_sequence) %>%
  group_by(shape_id) %>%
  summarise(
    lng = list(shape_pt_lon),
    lat = list(shape_pt_lat),
    .groups = "drop"
  ) %>%
  mutate(
    line = substr(shape_id, 1, 1),
    color = ifelse(line %in% names(shape_colors), shape_colors[line], "#000000")
  )


ui <- fluidPage(
  theme = bs_theme(bootswatch = "minty", version = 5),
  
  tags$head(
    tags$style(HTML("
      .art-card {
        position: relative;
        border-radius: 12px;
        overflow: hidden;
        box-shadow: 0 4px 8px rgba(0,0,0,0.1);
        margin-bottom: 30px;
        background-color: #fff;
        padding: 15px;
      }
      .station-title {
        font-size: 18px;
        font-weight: bold;
        margin-bottom: 5px;
        color: #333;
      }
      .art-title {
        font-size: 16px;
        font-weight: bold;
        margin-top: 10px;
        margin-bottom: 10px;
      }
      .art-image {
        width: 100%;
        height: auto;
        margin-bottom: 10px;
      }
    "))
  ),
  
  titlePanel("NYC Subway Art Map"),
  
  sidebarLayout(
    sidebarPanel(
      selectInput("selected_line", "Choose subway line:",
                  choices = c("All", sort(unique(shapes_grouped$line))),
                  selected = "All"),
      textInput("station_search", "Search station by name:", value = "")
    ),
    mainPanel(
      leafletOutput("subway_map", height = "700px"),
      uiOutput("art_info")
    )
  )
)

server <- function(input, output, session) {
  
  output$subway_map <- renderLeaflet({
    leaflet() %>%
      addTiles() %>%
      setView(lng = -73.98, lat = 40.75, zoom = 11)
  })
  
  observe({
    leafletProxy("subway_map") %>% clearShapes() %>% clearMarkers()
    
    selected_line <- input$selected_line
    shapes_to_draw <- if (selected_line == "All") shapes_grouped else shapes_grouped %>%
      mutate(color = ifelse(line == selected_line, color, "lightgray"))
    
    for (i in 1:nrow(shapes_to_draw)) {
      leafletProxy("subway_map") %>%
        addPolylines(
          lng = unlist(shapes_to_draw$lng[i]),
          lat = unlist(shapes_to_draw$lat[i]),
          color = shapes_to_draw$color[i],
          weight = ifelse(shapes_to_draw$line[i] == selected_line, 4, 2),
          opacity = ifelse(shapes_to_draw$line[i] == selected_line, 1, 0.3)
        )
    }
    
    leafletProxy("subway_map") %>%
      addCircleMarkers(
        data = station_with_coords,
        lng = ~stop_lon,
        lat = ~stop_lat,
        radius = 5,
        color = "black",
        fillColor = "white",
        fillOpacity = 1,
        weight = 1,
        label = ~station_name,
        layerId = ~station_name,
        labelOptions = labelOptions(
          direction = "auto",
          style = list("font-weight" = "bold", "font-size" = "13px")
        )
      )
  })
  
  observe({
    selected_station <- NULL
    
    if (input$station_search != "") {
      match <- station_with_coords %>%
        filter(grepl(input$station_search, station_name, ignore.case = TRUE)) %>%
        slice(1)
      if (nrow(match) > 0) selected_station <- match$station_name
    }
    
    if (!is.null(input$subway_map_marker_click$id)) {
      selected_station <- input$subway_map_marker_click$id
    }
    
    if (!is.null(selected_station)) {
      output$art_info <- renderUI({
        artworks <- mta_art %>%
          filter(station_name == selected_station, !is.na(art_image_link), art_image_link != "")
        
        if (nrow(artworks) == 0) return(tags$p("No images available for this station."))
        
        cards <- lapply(1:nrow(artworks), function(i) {
          link <- artworks$art_image_link[i]
          tryCatch({
            html <- read_html(link)
            img <- html %>% html_nodes("img") %>% html_attr("src") %>% .[1]
            if (!startsWith(img, "http")) img <- paste0("https://www.mta.info", img)
            
            tags$div(class = "art-card",
                     tags$div(class = "station-title", selected_station),
                     tags$div(class = "art-title", artworks$art_title[i]),
                     tags$img(src = img, class = "art-image"),
                     tags$p(tags$b("Artist: "), artworks$artist[i]),
                     tags$p(tags$b("Material: "), artworks$art_material[i]),
                     tags$p(tags$b("Year: "), artworks$art_date[i]),
                     tags$p(tags$b("Description: "), artworks$art_description[i])
            )
          }, error = function(e) NULL)
        })
        
        do.call(tagList, cards)
      })
    }
  })
}

shinyApp(ui, server)

