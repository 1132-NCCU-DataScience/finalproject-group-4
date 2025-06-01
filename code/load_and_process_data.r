library(readxl)
library(dplyr)
library(purrr)
library(stringr)
library(caret)
library(randomForest)
library(Metrics)
library(pracma) # For trapz function

# --- Function to load and process all subject CSV data ---
load_and_process_data <- function() {
  # Read label file
  labels_df <- tryCatch({
    read_excel(
      LABEL_FILE,
      col_types = c("text", rep("numeric", 5)) # Assuming Filename is text, rest numeric
    ) %>%
      select(
        Filename,
        `Swing Path Accuracy`,
        `Swing Speed Smoothness`,
        `Wrist Rotation Timing Accuracy`,
        `Hit Timing Accuracy`,
        `Ball Contact Position Accuracy`
      ) %>%
      rename_with(~make.names(.)) # Make column names R-friendly
  }, error = function(e) {
    message(paste("Error reading label file:", e$message))
    return(NULL)
  })

  if (is.null(labels_df)) return(data.frame())
  
  # Prepare labels_df for merging by making Filename the key (like index)
  # For easier lookup, we can keep it as a column and use dplyr::left_join later

  all_features_list <- list()
  csv_files <- list.files(DATA_PATH, pattern = "^h.*\\.csv$", full.names = TRUE)

  for (csv_path in csv_files) {
    tryCatch({
      base_name <- basename(csv_path)
      subject_id <- str_split(base_name, "_")[[1]][1]

      # Check if label exists (using Filename column)
      if (!subject_id %in% labels_df$Filename) {
        message(paste("Warning:", subject_id, "has no corresponding label"))
        next
      }

      # Read and process CSV data
      df <- read.csv(csv_path)
      required_columns <- c('time', 'acc_x', 'acc_y', 'acc_z', 'gyro_x', 'gyro_y', 'gyro_z')
      if (!all(required_columns %in% colnames(df))) {
        message(paste("File", base_name, "missing required columns, skipping"))
        next
      }

      df <- df %>%
        rename(
          timestamp = time,
          vx = acc_x,
          vy = acc_y,
          vz = acc_z,
          wx = gyro_x,
          wy = gyro_y,
          wz = gyro_z
        )

      # Feature extraction
      features <- extract_swing_features(df)
      if (nrow(features) == 0) {
        next
      }
      
      features$subject_id <- subject_id # This is the 'Filename' from labels

      # Merge label data
      # Ensure subject_id in features matches 'Filename' in labels_df for joining
      label_data_row <- labels_df %>% filter(Filename == subject_id)
      
      if(nrow(label_data_row) == 1){
         # Select only the target columns from label_data_row
        target_label_cols <- label_data_row %>%
            select(Swing.Path.Accuracy, Swing.Speed.Smoothness, Wrist.Rotation.Timing.Accuracy,
                   Hit.Timing.Accuracy, Ball.Contact.Position.Accuracy)
        
        # Repeat the label row for each swing feature extracted for that subject
        features_with_labels <- bind_cols(features, target_label_cols[rep(1, nrow(features)), ])
        all_features_list <- append(all_features_list, list(features_with_labels))
      } else {
        message(paste("Warning: Could not find unique label for", subject_id))
      }

    }, error = function(e) {
      message(paste("Error processing", base_name, ":", e$message))
    })
  }
  
  if (length(all_features_list) > 0) {
    return(bind_rows(all_features_list))
  } else {
    return(data.frame())
  }
}