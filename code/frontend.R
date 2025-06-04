library(shiny)
library(shinythemes)
library(plotly)
library(fmsb)
library(DT)
library(shinydashboard)
library(shinyWidgets)

# Define UI
ui <- navbarPage(
  title = "資料科學 第四組 羽球揮拍預測系統",
  theme = shinytheme("flatly"),
  
  tabPanel("Swing Analysis",
           fluidPage(
             # Custom CSS for enhanced styling
             tags$head(
               tags$style(HTML("
          .content-wrapper, .right-side {
            background-color: #f4f4f4;
          }
          .skin-blue .main-header .navbar {
            background-color: #3c8dbc;
          }
          .box.box-solid.box-primary > .box-header {
            background: #3c8dbc;
          }
          .slider-container {
            background: white;
            border-radius: 10px;
            padding: 20px;
            margin-bottom: 20px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
          }
          .metric-box {
            background: linear-gradient(45deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 15px;
            border-radius: 10px;
            margin-bottom: 10px;
            text-align: center;
          }
          .metric-value {
            font-size: 24px;
            font-weight: bold;
          }
          .metric-label {
            font-size: 12px;
            opacity: 0.8;
          }
        "))
             ),
             
             fluidRow(
               # Left Panel - Sensor Inputs
               column(4,
                      div(class = "slider-container",
                          h3("Sensor Data Input", style = "color: #3c8dbc; margin-bottom: 20px;"),
                          
                          h4("Acceleration Sensors", style = "color: #666; margin-bottom: 15px;"),
                          sliderInput("accel_x", "Acceleration_X (m/s²):",
                                      min = -20, max = 20, value = 0, step = 0.1,
                                      animate = animationOptions(interval = 300)),
                          
                          sliderInput("accel_y", "Acceleration_Y (m/s²):",
                                      min = -20, max = 20, value = 0, step = 0.1,
                                      animate = animationOptions(interval = 300)),
                          
                          sliderInput("accel_z", "Acceleration_Z (m/s²):",
                                      min = -20, max = 20, value = 9.8, step = 0.1,
                                      animate = animationOptions(interval = 300)),
                          
                          hr(),
                          
                          h4("Gyroscope Sensors", style = "color: #666; margin-bottom: 15px;"),
                          sliderInput("gyro_x", "Gyroscope_X (°/s):",
                                      min = -500, max = 500, value = 0, step = 1,
                                      animate = animationOptions(interval = 300)),
                          
                          sliderInput("gyro_y", "Gyroscope_Y (°/s):",
                                      min = -500, max = 500, value = 0, step = 1,
                                      animate = animationOptions(interval = 300)),
                          
                          sliderInput("gyro_z", "Gyroscope_Z (°/s):",
                                      min = -500, max = 500, value = 0, step = 1,
                                      animate = animationOptions(interval = 300))
                      )
               ),
               
               # Right Panel - Results and Visualizations
               column(8,
                      fluidRow(
                        # Performance Metrics Display
                        column(12,
                               h3("Performance Metrics", style = "color: #3c8dbc; margin-bottom: 20px;"),
                               fluidRow(
                                 column(2,
                                        div(class = "metric-box",
                                            div(class = "metric-value", textOutput("swing_path_score")),
                                            div(class = "metric-label", "Swing Path Accuracy")
                                        )
                                 ),
                                 column(2,
                                        div(class = "metric-box",
                                            div(class = "metric-value", textOutput("swing_speed_score")),
                                            div(class = "metric-label", "Swing Speed Smoothness")
                                        )
                                 ),
                                 column(3,
                                        div(class = "metric-box",
                                            div(class = "metric-value", textOutput("wrist_rotation_score")),
                                            div(class = "metric-label", "Wrist Rotation Timing")
                                        )
                                 ),
                                 column(2,
                                        div(class = "metric-box",
                                            div(class = "metric-value", textOutput("hit_timing_score")),
                                            div(class = "metric-label", "Hit Timing Accuracy")
                                        )
                                 ),
                                 column(3,
                                        div(class = "metric-box",
                                            div(class = "metric-value", textOutput("contact_position_score")),
                                            div(class = "metric-label", "Ball Contact Position")
                                        )
                                 )
                               )
                        )
                      ),
                      
                      br(),
                      
                      fluidRow(
                        # Radar Chart
                        column(6,
                               div(style = "background: white; border-radius: 10px; padding: 20px; box-shadow: 0 2px 4px rgba(0,0,0,0.1);",
                                   h4("Overall Performance Radar", style = "color: #3c8dbc; text-align: center;"),
                                   plotOutput("radar_chart", height = "350px")
                               )
                        ),
                        
                        # Time Series Plot
                        column(6,
                               div(style = "background: white; border-radius: 10px; padding: 20px; box-shadow: 0 2px 4px rgba(0,0,0,0.1);",
                                   h4("Sensor Data Visualization", style = "color: #3c8dbc; text-align: center;"),
                                   plotOutput("sensor_plot", height = "350px")
                               )
                        )
                      ),
                      
                      br(),
                      
                      fluidRow(
                        # Performance Trends
                        column(12,
                               div(style = "background: white; border-radius: 10px; padding: 20px; box-shadow: 0 2px 4px rgba(0,0,0,0.1);",
                                   h4("Performance Metrics Trend", style = "color: #3c8dbc; text-align: center;"),
                                   plotOutput("performance_trend", height = "300px")
                               )
                        )
                      )
               )
             )
           )
  ),
  
  # Additional tab for detailed analysis
  tabPanel("Detailed Analysis",
           fluidPage(
             h2("Advanced Swing Analysis", style = "color: #3c8dbc;"),
             fluidRow(
               column(12,
                      DT::dataTableOutput("detailed_table")
               )
             )
           )
  )
)

# Define Server
server <- function(input, output, session) {
  
  # Reactive expressions for calculating scores
  swing_path_accuracy <- reactive({
    # Calculate based on acceleration consistency
    accel_magnitude <- sqrt(input$accel_x^2 + input$accel_y^2 + input$accel_z^2)
    score <- max(0, min(100, 100 - abs(accel_magnitude - 12) * 5))
    round(score, 1)
  })
  
  swing_speed_smoothness <- reactive({
    # Calculate based on gyroscope stability
    gyro_variance <- var(c(input$gyro_x, input$gyro_y, input$gyro_z))
    score <- max(0, min(100, 100 - gyro_variance/1000))
    round(score, 1)
  })
  
  wrist_rotation_timing <- reactive({
    # Calculate based on Z-axis gyroscope
    score <- max(0, min(100, 100 - abs(input$gyro_z) * 0.1))
    round(score, 1)
  })
  
  hit_timing_accuracy <- reactive({
    # Calculate based on overall sensor coordination
    coordination_factor <- abs(input$accel_x * input$gyro_x) + 
      abs(input$accel_y * input$gyro_y)
    score <- max(0, min(100, 100 - coordination_factor * 0.01))
    round(score, 1)
  })
  
  contact_position_accuracy <- reactive({
    # Calculate based on Z acceleration and X gyroscope
    contact_precision <- abs(input$accel_z - 9.8) + abs(input$gyro_x) * 0.1
    score <- max(0, min(100, 100 - contact_precision * 2))
    round(score, 1)
  })
  
  # Output for performance metrics
  output$swing_path_score <- renderText({
    paste0(swing_path_accuracy(), "%")
  })
  
  output$swing_speed_score <- renderText({
    paste0(swing_speed_smoothness(), "%")
  })
  
  output$wrist_rotation_score <- renderText({
    paste0(wrist_rotation_timing(), "%")
  })
  
  output$hit_timing_score <- renderText({
    paste0(hit_timing_accuracy(), "%")
  })
  
  output$contact_position_score <- renderText({
    paste0(contact_position_accuracy(), "%")
  })
  
  # Radar Chart
  output$radar_chart <- renderPlot({
    # Prepare data for radar chart
    scores <- c(
      swing_path_accuracy(),
      swing_speed_smoothness(), 
      wrist_rotation_timing(),
      hit_timing_accuracy(),
      contact_position_accuracy()
    )
    
    # Create data frame for fmsb
    radar_data <- data.frame(
      rbind(
        rep(100, 5),  # max values
        rep(0, 5),    # min values
        scores        # actual values
      )
    )
    colnames(radar_data) <- c("Swing Path", "Speed Smooth", "Wrist Timing", 
                              "Hit Timing", "Contact Position")
    
    # Create radar chart
    radarchart(radar_data,
               axistype = 1,
               pcol = rgb(0.2, 0.5, 0.5, 0.9),
               pfcol = rgb(0.2, 0.5, 0.5, 0.5),
               plwd = 4,
               cglcol = "grey",
               cglty = 1,
               axislabcol = "grey",
               caxislabels = seq(0, 100, 25),
               cglwd = 0.8,
               vlcex = 0.8)
  })
  
  # Sensor Data Visualization
  output$sensor_plot <- renderPlot({
    par(mfrow = c(2, 1), mar = c(4, 4, 2, 1))
    
    # Acceleration plot
    accel_data <- c(input$accel_x, input$accel_y, input$accel_z)
    barplot(accel_data, 
            names.arg = c("X", "Y", "Z"),
            col = c("#FF6B6B", "#4ECDC4", "#45B7D1"),
            main = "Acceleration (m/s²)",
            ylim = c(-20, 20),
            ylab = "Acceleration")
    abline(h = 0, col = "black", lty = 2)
    
    # Gyroscope plot  
    gyro_data <- c(input$gyro_x, input$gyro_y, input$gyro_z)
    barplot(gyro_data,
            names.arg = c("X", "Y", "Z"), 
            col = c("#96CEB4", "#FFEAA7", "#DDA0DD"),
            main = "Gyroscope (°/s)",
            ylim = c(-500, 500),
            ylab = "Angular Velocity")
    abline(h = 0, col = "black", lty = 2)
  })
  
  # Performance Trend
  output$performance_trend <- renderPlot({
    scores <- c(
      swing_path_accuracy(),
      swing_speed_smoothness(),
      wrist_rotation_timing(), 
      hit_timing_accuracy(),
      contact_position_accuracy()
    )
    
    metrics <- c("Swing Path", "Speed Smooth", "Wrist Timing", 
                 "Hit Timing", "Contact Position")
    
    par(mar = c(8, 4, 2, 1))
    barplot(scores,
            names.arg = metrics,
            col = rainbow(5, alpha = 0.7),
            main = "Current Performance Scores",
            ylab = "Score (%)",
            ylim = c(0, 100),
            las = 2,
            cex.names = 0.8)
    abline(h = seq(0, 100, 20), col = "gray", lty = 2)
  })
  
  # Detailed Analysis Table
  output$detailed_table <- DT::renderDataTable({
    data.frame(
      Metric = c("Swing Path Accuracy", "Swing Speed Smoothness", 
                 "Wrist Rotation Timing", "Hit Timing Accuracy", 
                 "Ball Contact Position"),
      Score = c(swing_path_accuracy(), swing_speed_smoothness(),
                wrist_rotation_timing(), hit_timing_accuracy(),
                contact_position_accuracy()),
      Status = ifelse(c(swing_path_accuracy(), swing_speed_smoothness(),
                        wrist_rotation_timing(), hit_timing_accuracy(),
                        contact_position_accuracy()) >= 75, "Excellent",
                      ifelse(c(swing_path_accuracy(), swing_speed_smoothness(),
                               wrist_rotation_timing(), hit_timing_accuracy(),
                               contact_position_accuracy()) >= 50, "Good", "Needs Improvement")),
      Acceleration_Input = paste("X:", input$accel_x, "Y:", input$accel_y, "Z:", input$accel_z),
      Gyroscope_Input = paste("X:", input$gyro_x, "Y:", input$gyro_y, "Z:", input$gyro_z)
    )
  }, options = list(pageLength = 10, scrollX = TRUE))
}

# Run the application
shinyApp(ui = ui, server = server)
