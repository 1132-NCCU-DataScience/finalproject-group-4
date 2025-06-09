# Load libraries
library(shiny)
library(shinythemes)
library(plotly)
library(fmsb)
library(DT)
library(shinydashboard)
library(shinyWidgets)
library(ggplot2)
library(reshape2)
library(htmltools)
library(flexdashboard)

# === 載入模型與預測函數 ===
model_path <- "results/model/multi_target_models.rds"
scaler_path <- "results/model/scaler.rds"

if (!file.exists(model_path) || !file.exists(scaler_path)) {
  stop("找不到模型檔案")
}

source("code/main.r")
models_list <- readRDS(model_path)
scaler <- readRDS(scaler_path)

# UI
ui <- tagList(
  navbarPage(
    title = "資料科學 第四組 羽球揮拍預測系統",
    theme = shinytheme("flatly"),
    
    tabPanel("Swing Analysis",
             fluidPage(
               tags$head(tags$style(HTML("
          .slider-container {
            background: #F5F5F5; border-radius: 10px; padding: 20px;
            margin-bottom: 20px; box-shadow: 0 2px 4px rgba(0,0,0,0.1);
          }
          .metric-box {
            background: linear-gradient(45deg, #667eea 0%, #764ba2 100%);
            color: white; padding: 15px; border-radius: 10px;
            margin: 5px; text-align: center;
          }
          .metric-value { font-size: 24px; font-weight: bold; }
          .metric-label { font-size: 12px; opacity: 0.8; }
          .badminton-slider .irs-handle > i {
            display: none !important;  /* 🔥 removes default gray circle */
          }
        
          .badminton-slider .irs-handle::before {
            content: '🏸';
            font-size: 30px;        /* 🎯 increase size here */
            position: absolute;
            top: -12px;             /* adjust vertical alignment */
            left: -10px;
          }
        
          .badminton-slider .irs-handle {
            background: transparent !important;
            border: none !important;
          }
        "))),
               
               fluidRow(
                 column(3,
                        div(class = "slider-container",
                            h3("Sensor Data Input", style = "color: #3c8dbc;"),
                            h4("Acceleration Sensors", style = "color: #666;"),
                            div(class = "badminton-slider",
                                sliderInput("accel_x", "Acceleration_X (m/s²):", -20, 20, 0, 0.1),
                                sliderInput("accel_y", "Acceleration_Y (m/s²):", -20, 20, 0, 0.1),
                                sliderInput("accel_z", "Acceleration_Z (m/s²):", -20, 20, 9.8, 0.1),
                                hr(),
                                h4("Gyroscope Sensors", style = "color: #666;"),
                                sliderInput("gyro_x", "Gyroscope_X (°/s):", -500, 500, 0, 1),
                                sliderInput("gyro_y", "Gyroscope_Y (°/s):", -500, 500, 0, 1),
                                sliderInput("gyro_z", "Gyroscope_Z (°/s):", -500, 500, 0, 1)
                            ),
                        )
                 ),
                 column(9,
                        fluidRow(
                          column(12,
                                 h3("Performance Metrics", style = "color: #3c8dbc; text-align: left; margin-bottom: 20px;"),
                                 
                                 # Wrap gauges in a flexbox-style row using HTML + CSS
                                 div(style = "display: flex; justify-content: space-between; gap: 10px;",
                                     div(style = "flex: 1;", gaugeOutput("gauge_path")),
                                     div(style = "flex: 1;", gaugeOutput("gauge_speed")),
                                     div(style = "flex: 1;", gaugeOutput("gauge_rotation")),
                                     div(style = "flex: 1;", gaugeOutput("gauge_hit")),
                                     div(style = "flex: 1;", gaugeOutput("gauge_contact"))
                                 )
                          )
                        ),
                        fluidRow(
                          style = "margin-top: -30px; margin-bottom: 10px;",
                          column(6,
                                 div(style = "margin-top: 0px; background: white; border-radius: 10px; padding: 0px;",
                                     h4("Overall Performance Radar", style = "color: #3c8dbc; text-align: center;"),
                                     plotOutput("radar_chart", height = "275px")
                                 ),
                                 div(style = "margin-top: 0px;",uiOutput("score_comment_box"))
                          ),
                          column(6,
                                 div(style = "margin-top: 0px; background: white; border-radius: 10px; padding: 0px;",
                                     h4("Feature Importance Heatmap", style = "color: #3c8dbc; text-align: center;"),
                                     plotOutput("feature_heatmap", height = "275px")
                                 ),
                                 div(style = "margin-top: 0px; background: white; border-radius: 10px; padding: 20px;",
                                     h4("Swing Metric Distributions", style = "color: #3c8dbc; text-align: center;"),
                                     plotOutput("boxplot_chart", height = "275px")
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
  ),
  
  tags$footer(
    style = "
    position: fixed;
    bottom: 0;
    left: 0;
    right: 0;
    background-color: #2c3e50;
    color: white;
    padding: 6px 12px;
    text-align: center;
    font-size: 14px;
    z-index: 9999;
    height: 36px;
  ",
    div(
      style = "display: flex; justify-content: center; align-items: center; gap: 6px;",  # 🔥 reduce gap here
      span("張詠軒，任善研，陳柏淵，林祖平，王煜凱，尤敏米茲夠"),
      tags$a(
        href = "https://github.com/1132-NCCU-DataScience/finalproject-group-4",
        target = "_blank",
        tags$img(src = "github-icon.png", height = "20px", style = "margin-left: 4px;")
      ),
      tags$a(
        href = "poster.jpg",
        target = "_blank",
        tags$img(
          src = "poster-icon.png",
          height = "23px",  # match GitHub icon
          width = "22px",
          style = "margin-left: 3px; object-fit: contain; margin-top: 1.5px;"
        )
      )
    )
  ),
)

# Server
server <- function(input, output, session) {
  swing_path_accuracy <- reactive({ round(max(0, min(100, 100 - abs(sqrt(input$accel_x^2 + input$accel_y^2 + input$accel_z^2) - 12) * 5)), 1) })
  swing_speed_smooth <- reactive({ round(max(0, min(100, 100 - var(c(input$gyro_x, input$gyro_y, input$gyro_z)) / 1000)), 1) })
  wrist_rotation_timing <- reactive({ round(max(0, min(100, 100 - abs(input$gyro_z) * 0.1)), 1) })
  hit_timing_accuracy <- reactive({ round(max(0, min(100, 100 - (abs(input$accel_x * input$gyro_x) + abs(input$accel_y * input$gyro_y)) * 0.01)), 1) })
  contact_position_accuracy <- reactive({ round(max(0, min(100, 100 - (abs(input$accel_z - 9.8) + abs(input$gyro_x) * 0.1) * 2)), 1) })
  
  output$gauge_path <- renderGauge({
    gauge(swing_path_accuracy(), min = 0, max = 100, symbol = "%", label = "Swing Path Accuracy", gaugeSectors(success = c(80, 100), warning = c(50, 79.9), danger = c(0, 49.9), colors = c("#b7e4c7", "#ffe599", "#f4cccc")))
  })
  output$gauge_speed <- renderGauge({
    gauge(swing_speed_smooth(), min = 0, max = 100, symbol = "%", label = "Swing Speed Smooth", gaugeSectors(success = c(80, 100), warning = c(50, 79.9), danger = c(0, 49.9), colors = c("#b7e4c7", "#ffe599", "#f4cccc")))
  })
  output$gauge_rotation <- renderGauge({
    gauge(wrist_rotation_timing(), min = 0, max = 100, symbol = "%", label = "Wrist Rotation Timing", gaugeSectors(success = c(80, 100), warning = c(50, 79.9), danger = c(0, 49.9), colors = c("#b7e4c7", "#ffe599", "#f4cccc")))
  })
  output$gauge_hit <- renderGauge({
    gauge(hit_timing_accuracy(), min = 0, max = 100, symbol = "%", label = "Hit Timing Accuracy", gaugeSectors(success = c(80, 100), warning = c(50, 79.9), danger = c(0, 49.9), colors = c("#b7e4c7", "#ffe599", "#f4cccc")))
  })
  output$gauge_contact <- renderGauge({
    gauge(contact_position_accuracy(), min = 0, max = 100, symbol = "%", label = "Ball Contact Position", gaugeSectors(success = c(80, 100), warning = c(50, 79.9), danger = c(0, 49.9), colors = c("#b7e4c7", "#ffe599", "#f4cccc")))
  })
  
  output$radar_chart <- renderPlot({
    scores <- c(swing_path_accuracy(), swing_speed_smooth(), wrist_rotation_timing(), hit_timing_accuracy(), contact_position_accuracy())
    radar_data <- data.frame(rbind(rep(100, 5), rep(0, 5), scores))
    colnames(radar_data) <- c("Swing Path", "Speed Smooth", "Wrist Timing", "Hit Timing", "Contact Position")
    
    # Tweak margins and scaling
    par(mar = c(2, 2, 2, 2))  # leave breathing room around plot
    
    radarchart(radar_data,
               axistype = 1,
               pcol = rgb(0.2, 0.5, 0.5, 0.9),
               pfcol = rgb(0.2, 0.5, 0.5, 0.5),
               plwd = 3,
               cglcol = "grey", cglty = 1, axislabcol = "grey",
               caxislabels = seq(0, 100, 25),
               cglwd = 0.8,
               vlcex = 1.2,        # label size
               title = "")         # no title
  })
  
  importance_matrix <- reactive({
    normalize <- function(val, max_val) round(abs(val) / max_val, 2)
    mat <- rbind(
      c(normalize(input$accel_x, 20), normalize(input$accel_y, 20), normalize(input$accel_z, 20), normalize(input$gyro_x, 500), normalize(input$gyro_y, 500), normalize(input$gyro_z, 500)),
      c(normalize(input$gyro_z, 500), normalize(input$gyro_y, 500), normalize(input$gyro_x, 500), normalize(input$accel_z, 20), normalize(input$accel_y, 20), normalize(input$accel_x, 20)),
      c(normalize(input$gyro_z, 500), normalize(input$gyro_y, 500), normalize(input$gyro_x, 500), normalize(input$accel_z, 20), normalize(input$accel_x, 20), normalize(input$accel_y, 20)),
      c(normalize(input$gyro_x * input$accel_x, 10000), normalize(input$gyro_y * input$accel_y, 10000), normalize(input$gyro_z * input$accel_z, 10000), normalize(input$gyro_x, 500), normalize(input$gyro_y, 500), normalize(input$gyro_z, 500)),
      c(normalize(input$accel_z - 9.8, 20), normalize(input$accel_y - input$accel_x, 20), normalize(input$gyro_x, 500), normalize(input$gyro_y, 500), normalize(input$gyro_z, 500), normalize(input$accel_x, 20))
    )
    colnames(mat) <- c("accel_x", "accel_y", "accel_z", "gyro_x", "gyro_y", "gyro_z")
    rownames(mat) <- c("Swing Path Accuracy", "Swing Speed Smoothness", "Wrist Rotation Timing", "Hit Timing Accuracy", "Ball Contact Position")
    mat
  })
  
  output$feature_heatmap <- renderPlot({
    df <- as.data.frame(importance_matrix())
    df$Metric <- rownames(df)
    df_melt <- melt(df, id.vars = "Metric", variable.name = "Feature", value.name = "Importance")
    
    ggplot(df_melt, aes(x = Feature, y = Metric, fill = Importance)) +
      geom_tile(color = "white") +
      geom_text(aes(
        label = sprintf("%.2f", Importance),
        color = Importance > 0.4  # threshold for white text
      )) +
      scale_color_manual(values = c("TRUE" = "white", "FALSE" = "black"), guide = "none") +
      scale_fill_gradient(low = "#dceefb", high = "#08306b", name = "Importance") +
      theme_minimal(base_size = 13) +
      theme(
        axis.text.x = element_text(angle = 0, hjust = 0.5, size = 11),
        axis.text.y = element_text(size = 11),
        axis.title.x = element_text(vjust = -1.5),
        # axis.title.x = element_text(margin = margin(t = 10)),  # << Adds space between ticks and "Feature"
        legend.title = element_text(size = 12, face = "bold"),
        legend.text = element_text(size = 10),
        plot.title = element_blank(),
        panel.grid = element_blank()
      ) +
      # axis.title.x = element_text(margin = margin(t = 10)) +
      labs(x = "Feature", y = "Metric")
  })
  
  comment_data <- data.frame(
    score = seq(1, 5, by = 0.2),
    comment = c(
      "揮拍動作需大幅改善，擊球時機與手腕控制不足",
      "需要加強手部協調與擊球位置精準度",
      "手腕控制較弱，建議多練習擊球穩定性",
      "擊球姿勢尚可，揮拍可再流暢些",
      "揮拍速度不錯，擊球時間略可改善",
      "整體表現中等，需注意手腕穩定性",
      "有進步空間，需改善擊球前置動作",
      "節奏感可再強化，整體尚可",
      "姿勢良好，唯手部協調仍需強化",
      "擊球位置還算穩定，但仍可更佳",
      "有潛力，揮拍較穩定",
      "整體表現良好，保持練習",
      "擊球時機已準確，揮拍流暢",
      "表現優良，小幅強化可達完美",
      "幾乎無可挑剔，續保持",
      "非常優秀，表現穩定且精準",
      "表現優異，技巧完整",
      "揮拍與擊球完美結合",
      "優秀穩定，手腕與時機協調佳",
      "近乎完美，細節極佳",
      "標準"
    ),
    stringsAsFactors = FALSE
  )
  
  score_fn <- function(...) {
    round(mean(c(...)) / 20, 1)
  }
  
  output$score_comment_box <- renderUI({
    avg_score <- round(mean(c(
      swing_path_accuracy(),
      swing_speed_smooth(),
      wrist_rotation_timing(),
      hit_timing_accuracy(),
      contact_position_accuracy()
    )) / 20, 1)
    
    idx <- which.min(abs(comment_data$score - avg_score))
    selected_comment <- comment_data$comment[idx]
    
    # Generate stars with partial fill logic
    stars_html <- ""
    for (i in 1:5) {
      fill_pct <- min(max(avg_score - (i - 1), 0), 1) * 100  # e.g., 0.9 → 90%
      stars_html <- paste0(
        stars_html,
        sprintf('
      <span style="display: inline-block; position: relative; width: 24px; height: 24px;">
        <span style="color: lightgray; position: absolute;">★</span>
        <span style="color: gold; width: %d%%; overflow: hidden; position: absolute; white-space: nowrap;">★</span>
      </span>',
                round(fill_pct)
        )
      )
    }
    
    fluidRow(
      column(12,
             div(
               style = "background: #FFF7E9; padding: 20px; border-radius: 12px; 
                 box-shadow: 0 2px 6px rgba(0,0,0,0.1); 
                 display: flex; justify-content: space-between; align-items: center; min-height:140px;",
               
               # 🖼 Left: Circle image
               tags$img(
                 src = "badminton-circle.png",  
                 height = "80px",
                 width = "80px",
                 style = "border-radius: 50%; object-fit: cover; border: 2px solid black;"
               ),
               
               # Left: Average Score
               div(
                 style = "text-align: left;",
                 h4("Average Score", style = "color: #3c8dbc;"),
                 div(
                   span(paste0(avg_score, " "), style = "font-size: 28px; font-weight: bold;"),
                   span(HTML(stars_html), style = "font-size: 22px; color: gold; padding-left: 6px;")
                 )
               ),
               
               # Right: Comment
               div(
                 style = "text-align: left; margin-right: 80px;",
                 h4("Comment", style = "color: #3c8dbc;"),
                 span(selected_comment, style = "font-size: 16px; margin-top: 20px; margin-right: 40px; display: block;"),
                 # span(selected_comment, style = "font-size: 16px;")
               )
             )
      )
    )
  })
  
  # Simulated history data for the boxplot
  set.seed(123)
  swing_history <- data.frame(
    Metric = factor(rep(c("Swing Path", "Speed Smooth", "Wrist Timing", "Hit Timing", "Contact Position"), each = 20),
                    levels = c("Swing Path", "Speed Smooth", "Wrist Timing", "Hit Timing", "Contact Position")),
    Score = c(
      rnorm(20, mean = 85, sd = 5),
      rnorm(20, mean = 90, sd = 3),
      rnorm(20, mean = 80, sd = 6),
      rnorm(20, mean = 75, sd = 7),
      rnorm(20, mean = 88, sd = 4)
    )
  )
  
  output$boxplot_chart <- renderPlot({
    # Live scores from input
    current_scores <- data.frame(
      Metric = factor(c("Swing Path", "Speed Smooth", "Wrist Timing", "Hit Timing", "Contact Position"),
                      levels = c("Swing Path", "Speed Smooth", "Wrist Timing", "Hit Timing", "Contact Position")),
      Score = c(
        swing_path_accuracy(),
        swing_speed_smooth(),
        wrist_rotation_timing(),
        hit_timing_accuracy(),
        contact_position_accuracy()
      )
    )
    
    # Combine with historical data
    combined_data <- rbind(swing_history, current_scores)
    
    # Plot
    ggplot(combined_data, aes(x = Metric, y = Score, fill = Metric)) +
      geom_boxplot(outlier.shape = NA, alpha = 0.6) +
      geom_point(data = current_scores, aes(x = Metric, y = Score), 
                 shape = 21, size = 3, fill = "black", color = "white", stroke = 1.2) +
      theme_minimal() +
      theme(
        axis.text.x = element_text(angle = 0, hjust = 0.5),
        axis.title.x = element_text(margin = ggplot2::margin(t = 12))
      ) +
      labs(x = "Metric", y = "Score", fill = "Metric")
  })
  
  # Detailed Analysis Table
  output$detailed_table <- DT::renderDataTable({
    data.frame(
      Metric = c("Swing Path Accuracy", "Swing Speed Smoothness", 
                 "Wrist Rotation Timing", "Hit Timing Accuracy", 
                 "Ball Contact Position"),
      Score = c(swing_path_accuracy(), swing_speed_smooth(),
                wrist_rotation_timing(), hit_timing_accuracy(),
                contact_position_accuracy()),
      Status = ifelse(c(swing_path_accuracy(), swing_speed_smooth(),
                        wrist_rotation_timing(), hit_timing_accuracy(),
                        contact_position_accuracy()) >= 75, "Excellent",
                      ifelse(c(swing_path_accuracy(), swing_speed_smooth(),
                               wrist_rotation_timing(), hit_timing_accuracy(),
                               contact_position_accuracy()) >= 50, "Good", "Needs Improvement")),
      Acceleration_Input = paste("X:", input$accel_x, "Y:", input$accel_y, "Z:", input$accel_z),
      Gyroscope_Input = paste("X:", input$gyro_x, "Y:", input$gyro_y, "Z:", input$gyro_z)
    )
  }, options = list(pageLength = 10, scrollX = TRUE))
}

shinyApp(ui = ui, server = server)