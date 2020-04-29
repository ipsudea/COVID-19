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


shinyUI(
    dashboardPage(
        title = "COVID-19: Modelos predictivos SIR de la IPS Universitaria",
        skin = "black",
        dashboardHeader(title = "Poblaciones"),
        dashboardSidebar(
            sidebarMenu(
            id = "",
            menuItem(text = "Antioquia", tabName = "antioquia", icon = icon("notes-medical")),
            menuItem(text = "EPS Priorizadas - SISPRO", tabName = "sispro", icon = icon("user-md")),
            menuItem(text = "EPS Priorizadas al 80%", tabName = "ochenta", icon = icon("ambulance"))
            )
            )
        ,
        dashboardBody(
            titlePanel(h1("COVID-19: Modelos predictivos SIR de la IPS Universitaria", align = "center")),
            tabItems(
                tabItem(tabName = "antioquia",
                        box(title = "Casos nacionales",
                            plotlyOutput("national_cases"),
                            width = 12),
                        box(title = "Modelos",
                            plotOutput("antioquia_plot"),
                            width = 12)
                        ),
                tabItem(tabName = "sispro",
                        tabBox(title = "Tipo de atención",
                               width = 12,
                               tabPanel("Hospitalización", 
                                        plotOutput("new_hosp"),
                                        h2("Máximo de pacientes acumulados mensuales", align = "center"),
                                        DTOutput("new_hosp_max")),
                               tabPanel("UCE no ventilada", 
                                        plotOutput("new_uce"),
                                        h2("Máximo de pacientes acumulados mensuales", align = "center"),
                                        DTOutput("new_uce_max")),
                               tabPanel("UCI ventilada",
                                        plotOutput("new_uci"),
                                        h2("Máximo de pacientes acumulados mensuales", align = "center"),
                                        DTOutput("new_uci_max"))
                               )
                        ),
                tabItem(tabName = "ochenta",
                        tabBox(title = "Tipo de atención",
                               width = 12,
                               tabPanel("Hospitalización", 
                                        plotOutput("hosp"),
                                        h2("Máximo de pacientes acumulados mensuales", align = "center"),
                                        DTOutput("hosp_max")),
                               tabPanel("UCE no ventilada", 
                                        plotOutput("uce"),
                                        h2("Máximo de pacientes acumulados mensuales", align = "center"),
                                        DTOutput("uce_max")),
                               tabPanel("UCI ventilada",
                                        plotOutput("uci"),
                                        h2("Máximo de pacientes acumulados mensuales", align = "center"),
                                        DTOutput("uci_max"))
                        )
                        )
                ))
        )
)