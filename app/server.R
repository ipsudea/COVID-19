library(tidyverse)      # Data manipulation
library(lubridate)      # Dates parsing
library(gganimate)      # Plot animations
library(RSocrata)       # Sources from the government
library(grid)           # Plotting
library(gghighlight)    # Highlighting
library(ggforce)        # Improved ggplot
library(plotly)         # Interactivity
library(ggpmisc)        # Peaks
library(readxl)         # Reading Excel
library(zoo)            # Time manipulation
library(writexl)        # Writing Excel
library(ggrepel)        # Text repel in plots
library(shiny)          # shiny
library(shinydashboard) # UI
library(shinyWidgets)   # UI
library(DT)             # Tables
library(knitr)          # May need LaTeX or text highlight
theme_set(theme_bw())

#----------------------------------------Base Code--------------------------------------------------#

## Data reading and manipulation

raw_data <- read.socrata("https://www.datos.gov.co/resource/gt2j-8ykr.csv") %>% 
    as_tibble()

antioquia_model <- read_csv("model_data.csv")
raw_ips <- read_excel("RESULTADOS PACIENTES COVID AL 17 de Abril 2020.xlsx")
raw_ips <- read_excel("BASE DE DATOS COVID-19 29-04-20.xlsx", skip = 6, n_max = 273)


covid <- raw_data %>% 
    mutate_at(vars(starts_with("fecha")), as_date)

cumulative <- covid %>%
    group_by(fecha_diagnostico, departamento) %>%
    summarize(n = n()) %>%
    group_by(departamento) %>% 
    mutate(acum = cumsum(n)) %>% 
    ungroup()

## National cases
### Parameters: Select departments, select vline, select breaks x&y, change title?, update date.
national_cases <- cumulative %>%
    filter(departamento %in% c("Antioquia", "Cundinamarca", "Cartagena D.T. y C.", "Valle del Cauca", "Bogotá D.C.")) %>% 
    ggplot(aes(x = fecha_diagnostico, y = acum, color = departamento)) +
    geom_line(size = 0.7) +
    geom_point(size = 1.1) +
    geom_vline(xintercept = as.numeric(ymd("2020-03-24")), linetype = 4, color = "black") +
    scale_x_date(date_breaks = "5 days", date_labels = "%d %b") +
    scale_y_continuous(breaks = seq(from = 0, to = 2400, by = 200), labels = scales::comma) +
    stat_peaks(aes(color = departamento, 
                   label = paste(..y.label..)), 
               geom = "text_repel",
               vjust = 1,
               span = NULL,
               y.label.fmt = "%.0f infectados") +
    theme(legend.position = "bottom",
          axis.text.x = element_text(size = 12),
          axis.text.y = element_text(size = 12),
          title = element_text(size = 16, face = "bold", family = "sans"),
          legend.text = element_text(margin = margin(r = 40, unit = "pt")),
          plot.title = element_text(hjust = 0.5),
          plot.subtitle = element_text(size = 9)) +
    labs(title = "COVID-19: Evolución de casos acumulados por departamento",
         subtitle = paste("Fuente: Instituto Nacional de Salud", Sys.Date()),
         x = NULL,
         y = NULL,
         color = NULL)


## Model performance

antioquia <- cumulative %>% 
    filter(departamento == "Antioquia",
           acum > 200)

colors <- c("acum" = "black", 
            "infectionsS1" = "darkblue", 
            "infectionsS2" ="darkorange", 
            "infectionsS3" = "darkred", 
            "n" = "grey")

tidy_antioquia <- antioquia_model %>%
    mutate(fecha_diagnostico = seq.Date(from = ymd("2020-04-07"), to = ymd("2021-04-07"), by = 1)) %>% 
    left_join(antioquia, by = "fecha_diagnostico") %>% 
    pivot_longer(cols = c("infectionsS1", "infectionsS2", "infectionsS3", "n", "acum"))

models_plot <- tidy_antioquia %>% 
    mutate(fecha_diagnostico = as_datetime(fecha_diagnostico)) %>%
    filter(name != "n") %>% 
    ggplot(aes(fecha_diagnostico, value, color = name)) +
    geom_line() +
    geom_point(size = 0.9, alpha = 0.4) +
    scale_color_manual(values = colors, labels = c("Casos confirmados", 
                                                   "Escenario pesimista (30%)", 
                                                   "Escenario intermedio (45%)",
                                                   "Escenario optimista (60%)")) +
    facet_zoom(xlim = c(ymd_hms("2020-04-05 00:00:00"), ymd_hms("2020-05-15 00:00:00")),
               ylim = c(0, 500), zoom.size = 1.2) +
    stat_peaks(aes(color = name, 
                   label = paste(..y.label.., ..x.label..)), 
               geom = "text", 
               vjust = -0.5,
               hjust = -0.04,
               span = NULL,
               x.label.fmt = "%d-%m(%b)",
               y.label.fmt = "%.0f pacientes") +
    theme(axis.text.y = element_text(size = 12),
          title = element_text(size = 16, face = "bold", family = "sans"),
          legend.position = "bottom",
          legend.text = element_text(margin = margin(r = 40, unit = "pt")),
          plot.title = element_text(hjust = 0.5),
          plot.subtitle = element_text(size = 10)
    ) +
    labs(title = "COVID-19: Antioquia - Modelo SIR - Población susceptible: 6.355.502",
         subtitle = "Fuente casos confirmados: Instituto Nacional de Salud (12/05/2020)",
         x = NULL,
         y = NULL,
         color = NULL)

# This function joins the data with the real information, needs to be modified once we get UCI and UCE
get_mixed <- function(raw_data, ips_data) {
    raw_data %>%
        mutate(date = seq.Date(from = ymd("2020-03-25"), to = ymd("2021-03-11"), by = 1)) %>% 
        left_join(ips_data, by = c("date" = "Fecha consulta")) %>%
        mutate(n = replace_na(n,0),
               acum = cumsum(n)) %>% 
        mutate(n = case_when(date > Sys.Date() ~ NA_real_,
                             TRUE ~ n),
               acum = case_when(date > Sys.Date() ~ NA_real_,
                                TRUE ~ acum))
}
# Hospitalización

hosp_data <- read_csv("hosp_data.csv")
new_hosp_data <- read_csv("new_hosp_data.csv")


ips_hosp <- raw_ips %>%
    filter(Resultado...62 == "Positivo") %>% 
    mutate(`Fecha consulta` = as_date(`Fecha consulta`)) %>% 
    group_by(`Fecha consulta`, ERP) %>%
    count() %>%
    ungroup()

hosp_mixed <- get_mixed(hosp_data, ips_hosp)
new_hosp_mixed <- get_mixed(new_hosp_data, ips_hosp)

tidy_hosp <- hosp_mixed %>% 
    pivot_longer(cols = c("hospS1", "hospS2", "hospS3", "hospS4", "acum"))

new_tidy_hosp <- new_hosp_mixed %>% 
    pivot_longer(cols = c("hospS1", "hospS2", "hospS3", "hospS4", "acum"))



fn_hosp_pt <- function(data, 
                       x_lim = c(ymd_hms("2020-04-05 00:00:00"), ymd_hms("2020-05-15 00:00:00")),
                       y_lim = c(0, 50),
                       pob = 767155,
                       upd_date = "(29/04/2020)"
                       ){
    hosp_colors <- c("acum" = "black", "hospS1" = "darkblue", "hospS2" = "darkorange", "hospS3" = "darkred", "hospS4" = "aquamarine4")
    hosp_alpha <- c("acum" = 1, "hospS1" = 0.4, "hospS2" = 0.4, "hospS3" = 0.4, "hospS4" = 1)

    data %>%
        mutate(date = as_datetime(date)) %>% 
        ggplot(aes(date, value, color = name, alpha = name)) +
        geom_line() +
        geom_point(size = 0.9, alpha = 0.2) +
        stat_peaks(aes(color = name, 
                       label = paste(..y.label.., ..x.label..)), 
                   geom = "text", 
                   vjust = -0.5,
                   hjust = -0.04,
                   span = NULL,
                   x.label.fmt = "%d-%m(%b)",
                   y.label.fmt = "%.0f pacientes") +
        scale_color_manual(values = hosp_colors, labels = c("Casos confirmados", 
                                                            "Escenario pesimista (30%)", 
                                                            "Escenario intermedio (45%)",
                                                            "Escenario optimista (60%)",
                                                            "Escenario ajustado (52%)")) +
        scale_alpha_manual(values = hosp_alpha, labels = NULL, guide = "none")  +
        facet_zoom(xlim = x_lim,
                   ylim = y_lim) +
        theme(axis.text.y = element_text(size = 12),
              title = element_text(size = 14, face = "bold", family = "sans"),
              legend.position = "bottom",
              legend.text = element_text(margin = margin(r = 40, unit = "pt")),
              plot.title = element_text(hjust = 0.5),
              plot.subtitle = element_text(size = 10)
        ) +
        labs(title = paste("COVID-19: Población hospitalizada - EPS priorizadas - Modelo SIR - Población susceptible:", scales::comma(pob)),
             subtitle = paste("Fuente casos confirmados: Puesto de mando unificado - IPS Universitaria", upd_date),
             x = NULL,
             y = NULL,
             color = NULL,
             alpha = NULL) 
}

# Aggregation function
calculate_maxima <- function(data) {
    data %>% 
        group_by(fecha = tsibble::yearmonth(date)) %>% 
        summarize(ajustado = max(hospS4), pesimista = max(hospS1),
                  intermedio = max(hospS2), optimista = max(hospS3))
}

# UCE

uce_data <- read_csv("uce_data.csv")
new_uce_data <- read_csv("new_uce_data.csv")
## Let's mix it with the hospitalization data for now

ips_uce <- raw_ips %>%
    filter(Resultado...62 == "Positivo",
           str_detect(Servicio, "MI|UCE|SAI")) %>% 
    mutate(`Fecha consulta` = as_date(`Fecha consulta`)) %>% 
    group_by(`Fecha consulta`, ERP) %>%
    count() %>%
    ungroup()

tidy_uce <- get_mixed(uce_data, ips_uce) %>% 
    dplyr::select(-n, -acum, -ERP) %>% 
    pivot_longer(cols = 1:4)

new_tidy_uce <- get_mixed(new_uce_data, ips_hosp) %>% 
    dplyr::select(-n, -acum, -ERP) %>% 
    pivot_longer(cols = 1:4)

fn_uce_pt <- function(data, 
                       x_lim = c(ymd_hms("2020-04-05 00:00:00"), ymd_hms("2020-05-15 00:00:00")),
                       y_lim = c(0, 50),
                       pob = 767155,
                       upd_date = "(19/04/2020)"
){
    uce_colors <- c("icuS1" = "darkblue", "icuS2" = "darkorange", "icuS3" = "darkred", "icuS4" = "aquamarine4")
    uce_alpha <- c("icuS1" = 0.4, "icuS2" = 0.4, "icuS3" = 0.4, "icuS4" = 1)
    
    data %>%
        mutate(date = as_datetime(date)) %>% 
        ggplot(aes(date, value, color = name, alpha = name)) +
        geom_line() +
        geom_point(size = 0.9, alpha = 0.2) +
        stat_peaks(aes(color = name, 
                       label = paste(..y.label.., ..x.label..)), 
                   geom = "text", 
                   vjust = -0.5,
                   hjust = -0.04,
                   span = NULL,
                   x.label.fmt = "%d-%m(%b)",
                   y.label.fmt = "%.0f pacientes") +
        scale_color_manual(values = uce_colors, labels = c( 
            "Escenario pesimista (30%)", 
            "Escenario intermedio (45%)",
            "Escenario optimista (60%)",
            "Escenario ajustado (52%)")) +
        scale_alpha_manual(values = uce_alpha, labels = NULL, guide = "none")  +
        facet_zoom(xlim = x_lim,
                   ylim = y_lim) +
        theme(axis.text.y = element_text(size = 12),
              title = element_text(size = 14, face = "bold", family = "sans"),
              legend.position = "bottom",
              legend.text = element_text(margin = margin(r = 40, unit = "pt")),
              plot.title = element_text(hjust = 0.5),
              plot.subtitle = element_text(size = 10)
        ) +
        labs(title = paste("COVID-19: Población en UCE - EPS priorizadas - Modelo SIR - Población susceptible:", scales::comma(pob)),
             subtitle = paste("Fuente casos confirmados: Puesto de mando unificado - IPS Universitaria", upd_date),
             x = NULL,
             y = NULL,
             color = NULL,
             alpha = NULL) 
}

# UCE Aggregation function
calculate_maxima_uce <- function(data) {
    data %>% 
        group_by(fecha = tsibble::yearmonth(date)) %>% 
        summarize(ajustado = max(icuS4), pesimista = max(icuS1),
                  intermedio = max(icuS2), optimista = max(icuS3))
}

# UCI



uci_data <- read_csv("uci_data.csv")
new_uci_data <- read_csv("new_uci_data.csv")

ips_uci <- raw_ips %>%
    filter(Resultado...62 == "Positivo",
           Servicio == "UCI-V 4" | Servicio == "UCI MEDICO QUIRURGICA" | 
               Servicio == "UCI 5") %>% 
    mutate(`Fecha consulta` = as_date(`Fecha consulta`)) %>% 
    group_by(`Fecha consulta`, ERP) %>%
    count() %>%
    ungroup()

new_tidy_uci <- get_mixed(new_uci_data , ips_uci) %>%
    pivot_longer(cols = c(1:4, "n"))

tidy_uci <- get_mixed(uci_data , ips_hosp) %>% 
    dplyr::select(-n, -acum, -ERP) %>% 
    pivot_longer(cols = 1:4)

fn_uci_pt <- function(data, 
                      x_lim = c(ymd_hms("2020-04-05 00:00:00"), ymd_hms("2020-05-05 00:00:00")),
                      y_lim = c(0, 50),
                      pob = 767155,
                      upd_date = "(19/04/2020)"
){
    uci_colors <- c("ventS1" = "darkblue", "ventS2" = "darkorange", "ventS3" = "darkred", "ventS4" = "aquamarine4")
    uci_alpha <- c("ventS1" = 0.4, "ventS2" = 0.4, "ventS3" = 0.4, "ventS4" = 1)
    
    data %>%
        mutate(date = as_datetime(date)) %>% 
        ggplot(aes(date, value, color = name, alpha = name)) +
        geom_line() +
        geom_point(size = 0.9, alpha = 0.2) +
        stat_peaks(aes(color = name, 
                       label = paste(..y.label.., ..x.label..)), 
                   geom = "text", 
                   vjust = -0.5,
                   hjust = -0.04,
                   span = NULL,
                   x.label.fmt = "%d-%m(%b)",
                   y.label.fmt = "%.0f pacientes") +
        scale_color_manual(values = uci_colors, labels = c( 
            "Escenario pesimista (30%)", 
            "Escenario intermedio (45%)",
            "Escenario optimista (60%)",
            "Escenario ajustado (52%)")) +
        scale_alpha_manual(values = uci_alpha, labels = NULL, guide = "none")  +
        facet_zoom(xlim = x_lim,
                   ylim = y_lim) +
        theme(axis.text.y = element_text(size = 12),
              title = element_text(size = 14, face = "bold", family = "sans"),
              legend.position = "bottom",
              legend.text = element_text(margin = margin(r = 40, unit = "pt")),
              plot.title = element_text(hjust = 0.5),
              plot.subtitle = element_text(size = 10)
        ) +
        labs(title = paste("COVID-19: Población en UCI - EPS priorizadas - Modelo SIR - Población susceptible:", scales::comma(pob)),
             subtitle = paste("Fuente casos confirmados: Puesto de mando unificado - IPS Universitaria", upd_date),
             x = NULL,
             y = NULL,
             color = NULL,
             alpha = NULL) 
}

# UCI Aggregation function
calculate_maxima_uci <- function(data) {
    data %>% 
        group_by(fecha = tsibble::yearmonth(date)) %>% 
        summarize(ajustado = max(ventS4), pesimista = max(ventS1),
                  intermedio = max(ventS2), optimista = max(ventS3))
}



# Server logic - Programming ---------------------------------------------------------------------------------------------------------#
shinyServer(function(input, output) {
    # National cases
    output$national_cases <- renderPlotly(ggplotly(national_cases))
    output$antioquia_plot <- renderPlot(models_plot)
    
    #SISPRO
    output$new_hosp <- renderPlot(fn_hosp_pt(new_tidy_hosp))
    output$new_hosp_max <- renderDT(calculate_maxima(new_hosp_mixed))
    output$new_uce <- renderPlot(fn_uce_pt(new_tidy_uce))
    output$new_uce_max <- renderDT(calculate_maxima_uce(get_mixed(new_uce_data, ips_hosp) %>% 
                                                             dplyr::select(-n, -acum, -ERP)))
    output$new_uci <- renderPlot(fn_uci_pt(new_tidy_uci))
    output$new_uci_max <- renderDT(calculate_maxima_uci(get_mixed(new_uci_data, ips_hosp) %>% 
                                                            dplyr::select(-n, -acum, -ERP)))
    
    #Ochenta
    output$hosp <- renderPlot(fn_hosp_pt(tidy_hosp, pob = 1986560))
    output$hosp_max <- renderDT(calculate_maxima(hosp_mixed))
    output$uce <- renderPlot(fn_uce_pt(tidy_uce, pob = 1986560))
    output$uce_max <- renderDT(calculate_maxima_uce(get_mixed(new_uce_data, ips_hosp) %>% 
                                                            dplyr::select(-n, -acum, -ERP)))
    output$uci <- renderPlot(fn_uci_pt(tidy_uci, pob = 1986560))
    output$uci_max <- renderDT(calculate_maxima_uci(get_mixed(new_uci_data, ips_hosp) %>% 
                                                            dplyr::select(-n, -acum, -ERP)))
}
)
