## Group: Hawk Ticehurst, Alex Davis, Zach Wu, Ishan Mitra
## Info 201: Final Project
## College Data Web App Server

library(shiny)
library(ggplot2)
library(mapdata)
library(dplyr)
library(zipcode)
library(plotly)
data(zipcode)

## Read in cost by location data
costs_data <- read.csv("data/uni_costs_by_location.csv")
costs_data$ZIP = clean.zipcodes(costs_data$ZIP)

## Read in earnings by college type data
earnings_data <- read.csv("data/uni_earnings_by_college_type.csv")

## Read in repayment rate by family income data
debt_data <- read.csv("data/uni_repayment_by_income.csv")

## Read in debt by family income data
student_debt_data <- read.csv("data/uni_debt_by_income.csv")

server <- function(input, output) {
  ############### Cost By Location ###############
  
  ## Filter cost by location data by inputs
  get_data <- reactive({
    if (is.element(input$state, costs_data$STATE)) {
      costs_data <- filter(costs_data, STATE == input$state)
    }
    
    costs_data <- costs_data %>% 
      filter(STATE != "AS" & STATE != "MH" & STATE != "FM" 
             & STATE != "MP" & STATE != "GU" & STATE != "PW" 
             & STATE != "PR" & STATE != "VI")
    if(input$tuition_type == 0) {
      costs_data <- costs_data %>%
        filter(INSTATE_TUITION <= max(input$tuition_range) &
               INSTATE_TUITION >= min(input$tuition_range))
    } else {
      costs_data <- costs_data %>%
        filter(OUTOFSTATE_TUITION <= max(input$tuition_range) &
                OUTOFSTATE_TUITION >= min(input$tuition_range))
    }
              
    return(costs_data)
  })
  
  ## Render cost by location plot
  output$plot <- renderPlotly({
    usa_map <- map_data("state")
    costs_data <- get_data()
    costs_data <- left_join(costs_data, zipcode, by = c("ZIP" = "zip"))
    costs_data$city <- NULL
    costs_data$state <- NULL
    
    g <- list(
      scope = 'usa',
      projection = list(type = 'albers usa'),
      showland = TRUE,
      landcolor = toRGB("gray95"),
      subunitcolor = toRGB("gray85"),
      countrycolor = toRGB("gray85"),
      countrywidth = 0.5,
      subunitwidth = 0.5
    )
    
    cost_plot <- plot_geo(costs_data, y = ~latitude, x = ~longitude) %>%
      add_markers(
        text = ~paste(paste("School:", costs_data$NAME), 
                      paste0("In-State Tuition: $", costs_data$INSTATE_TUITION), 
                      paste0("Out-Of-State Tuition: $", costs_data$OUTOFSTATE_TUITION), 
                      sep = "<br />"),
        hoverinfo = "text"
      ) %>%
      layout(
        title = 'College Costs in the United States', geo = g
      )
    
    ggplotly(cost_plot) %>% config(displayModeBar = FALSE)
  })
  
  # Calculate cost by location summary message
  message <- reactive({
    costs_data <- get_data()
    state_message <- ""
    if (length(unique(costs_data$STATE)) > 1) {
      state_message <- paste0(length(unique(costs_data$STATE)), " states,")
    } else if (length(unique(costs_data$STATE)) == 1) {
      state_message <- paste0(costs_data$STATE[1], ", ")
    }
    paste0("Data shows ", nrow(costs_data),
           " college(s)/universitie(s) in ", state_message,
           " with a median in-state tuition of $", median(costs_data$INSTATE_TUITION),
           " and a median out-of state tuition of $", median(costs_data$OUTOFSTATE_TUITION), 
           ".")
  })
  
  ## Render cost by location summary message
  output$message <- renderText({
    output_message <- message()
    paste0(message())
  })
  
  
  ############### Earnings By College Type ###############
  
  ## Get the earnings data based on the type of college selected
  get_earnings <- reactive({
    df <- earnings_data %>%
      filter(COLLEGE_TYPE == input$typeOfCollege) %>%
      arrange_(paste0("desc(",input$earnings_data_type,")"))
    
    return(df)
  })
  
  
  ## Output a plotly bar graph of the top 15 colleges with the highest earnings
  output$distPlot2 <- renderPlotly({
    earnings_df <- get_earnings()
    earnings_df <- earnings_df[1:15,]
    
    p <- ggplot(data=earnings_df, aes_string(x="NAME", y=input$earnings_data_type)) +
      geom_bar(stat="identity") + 
      ggtitle("Top 15 College Earnings By Years After Graduation & College Type") +
      ylab("Average Earnings") + 
      xlab("Colleges") + 
      guides(fill=FALSE) + 
      coord_flip()
    
    ggplotly(p) %>% config(displayModeBar = FALSE)
  })
  
  ############### Repayment Rate By Family Income ###############
  
  output$plot3 <- renderPlot({
    get_university <- debt_data %>%
      filter(NAME == input$collegeInput) %>%
      select(contains(input$repaymentYears))
      df <- data.frame(x = colnames(get_university), y = as.numeric(get_university[1, ]))
      
      ggplot(df,aes(x = x, y = y)) +
      geom_bar(stat = "identity") +
        geom_text(aes(label = round(y,digits = 2), vjust = -0.3, size = 3.5)) +
        geom_bar(stat = "identity", color = "steelblue", fill = "steelblue") +
        xlab("Repayment by Income (0 - 30K, 30 - 75k, 75k+)") +
        ylab("Repayment Rate (%)") +
      geom_bar(stat="identity", color="steelblue", fill="steelblue") +
      ggtitle(input$collegeInput) +
      theme_minimal()
  })
  
  ############### Debt By Student Subgroup ###############
  
  order_college_debt <- reactive({
    student_debt_data %>%
      arrange_(paste0("desc(",input$studentSubgroup,")"))
  })
  
  output$distPlot4 <- renderPlotly({
    debt_df <- order_college_debt()
    debt_df <- na.omit(debt_df)
    if(input$debtRange == 0) {
      debt_df <- debt_df[1:15,]
    } else {
      debt_df <- tail(debt_df, n=15)
    }
    
    p <- ggplot(data=debt_df, aes_string(x="NAME", y=input$studentSubgroup)) +
      geom_bar(stat="identity") + 
      ggtitle("College Debt by Income Level") +
      ylab("Debt (in US Dollars)") + 
      xlab("Colleges") + 
      guides(fill=FALSE) + 
      coord_flip()
    
    ggplotly(p) %>% config(displayModeBar = FALSE)
  })
}