# Load necessary libraries
library(readxl)
library(dplyr)
library(purrr)
library(stringr)
library(caret)
library(randomForest)
library(Metrics)
library(pracma) # For trapz function

# --- Settings ---
DATA_PATH <- 'data/time_series_data_csv/'
LABEL_FILE <- 'data/label/label_and_comments.xlsx'
MODEL_DIR <- 'results/model/'
SAMPLE_RATE <- 203 # Not explicitly used in the feature extraction logic provided, but good to have if needed.

# Create model directory if it doesn't exist
if (!dir.exists(MODEL_DIR)) {
  dir.create(MODEL_DIR, recursive = TRUE, showWarnings = FALSE)
}

# --- Function to extract swing features from a data frame ---
extract_swing_features <- function(df) {
  features_list <- list()

  # Validate data
  if (nrow(df) == 0 || !("timestamp" %in% colnames(df))) {
    return(data.frame())
  }

  tryCatch({
    # Calculate composite magnitudes
    df$v_norm <- sqrt(df$vx^2 + df$vy^2 + df$vz^2)
    df$w_norm <- sqrt(df$wx^2 + df$wy^2 + df$wz^2)
  }, error = function(e) {
    message(paste("Missing sensor data columns:", e$message))
    return(data.frame())
  })

  # Detect swing segments
  tryCatch({
    time_diff <- c(0, diff(df$timestamp)) # diff() then pad with 0 at start
    swing_groups <- cumsum(time_diff > 50) # Threshold of 50ms for new swing
  }, error = function(e) {
    message(paste("Timestamp processing error:", e$message))
    return(data.frame())
  })
  
  df$swing_group_id <- swing_groups
  
  # Split data by swing_group_id
  grouped_swings <- split(df, df$swing_group_id)

  for (swing_id_chr in names(grouped_swings)) {
    group <- grouped_swings[[swing_id_chr]]
    swing_id <- as.integer(swing_id_chr) # Group names are characters

    # Swing validity check
    if (nrow(group) < 10 || max(group$v_norm, na.rm = TRUE) < 1e-6) {
      next
    }

    tryCatch({
      # Time processing
      time_sec <- (group$timestamp - group$timestamp[1]) / 1000.0
      peak_idx_in_group <- which.max(group$v_norm)

      # Feature calculation
      if (peak_idx_in_group > length(time_sec)) { # Should not happen if peak_idx is from group
          message(paste("Peak index out of bounds for swing", swing_id))
          next
      }
      
      # Ensure there are at least two points for trapezoidal integration
      w_integral_val <- if (length(time_sec) > 1 && length(group$w_norm) > 1) {
                           trapz(time_sec, group$w_norm)
                         } else {
                           0 # Or some other default for single point "integral"
                         }

      feat <- data.frame(
        swing_id = swing_id,
        max_v = max(group$v_norm, na.rm = TRUE),
        mean_v = mean(group$v_norm, na.rm = TRUE),
        max_w = max(group$w_norm, na.rm = TRUE),
        accel_time = time_sec[peak_idx_in_group],
        decel_time = time_sec[length(time_sec)] - time_sec[peak_idx_in_group],
        v_peak_time = time_sec[peak_idx_in_group],
        w_integral = w_integral_val 
      )
      features_list <- append(features_list, list(feat))
    }, error = function(e) {
      message(paste("Error extracting features for swing", swing_id, ":", e$message))
    })
  }
  
  if (length(features_list) > 0) {
    return(bind_rows(features_list))
  } else {
    return(data.frame())
  }
}

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

# --- Function to train multi-target scoring model ---
train_models <- function(data) { # Changed name to train_models (plural)
  if (nrow(data) == 0) {
    stop("No valid training data")
  }

  feature_cols <- c('max_v', 'mean_v', 'max_w', 'accel_time', 'decel_time', 'v_peak_time', 'w_integral')
  target_cols <- c(
    'Swing.Path.Accuracy',
    'Swing.Speed.Smoothness',
    'Wrist.Rotation.Timing.Accuracy',
    'Hit.Timing.Accuracy',
    'Ball.Contact.Position.Accuracy'
  ) # Adjusted to R-friendly names

  X <- data[, feature_cols]
  y <- data[, target_cols]

  # Data standardization
  # caret's preProcess stores scaling parameters
  scaler <- preProcess(X, method = c("center", "scale"))
  X_scaled <- predict(scaler, X)
  
  # Split dataset (caret can be used for more robust splitting)
  # Using a simple random split here for brevity
  set.seed(42) # for reproducibility
  train_indices <- createDataPartition(y[[1]], p = 0.8, list = FALSE, times = 1) # Stratify by first target
  
  X_train <- X_scaled[train_indices, ]
  y_train <- y[train_indices, ]
  X_test <- X_scaled[-train_indices, ]
  y_test <- y[-train_indices, ]

  models_list <- list()
  message('Model RMSE per target:')
  
  for (i in 1:length(target_cols)) {
    target_name <- target_cols[i]
    
    # Formula for randomForest
    # Ensure target_name is valid for formula
    formula_str <- paste0("`", target_name, "` ~ .") # Use backticks for special characters in names
    
    # Create a temporary data frame for training this specific target
    # randomForest expects y to be a vector if x is a matrix, or use formula with data frame
    train_df_for_rf <- cbind(X_train, y_train[, target_name, drop = FALSE])
    colnames(train_df_for_rf)[ncol(train_df_for_rf)] <- target_name # Ensure the name is correct

    model <- randomForest(
      formula = as.formula(formula_str),
      data = train_df_for_rf,
      ntree = 200,
      # maxnodes = 2^8, # max_depth equivalent; randomForest uses nodesize or maxnodes.
                         # ranger package has max.depth. For simplicity, let RF decide or tune nodesize.
      random.state = 42, # randomForest doesn't have random.state, set.seed outside is typical
      importance = FALSE, # Set TRUE if you need variable importance
      # n_jobs = -1 (parallel processing requires doParallel or similar setup)
    )
    models_list[[target_name]] <- model
    
    # Model evaluation
    y_pred <- predict(model, X_test)
    rmse_val <- rmse(actual = y_test[[target_name]], predicted = y_pred)
    message(paste0("- ", target_name, ": ", sprintf("%.2f", rmse_val)))
  }
  
  # Save models and scaler
  saveRDS(models_list, file.path(MODEL_DIR, 'multi_target_models.rds'))
  saveRDS(scaler, file.path(MODEL_DIR, 'scaler.rds'))
  
  return(list(models = models_list, scaler = scaler))
}

# --- Function to extract features for a single swing instance ---
# This function in Python used fixed values for time-related features.
# Replicating that logic. It assumes raw_data is a snapshot, not a series.
extract_single_swing_features <- function(raw_data) {
  tryCatch({
    if (length(raw_data) != 6) {
      stop("Requires 6 numeric values (ax, ay, az, gx, gy, gz)")
    }
    
    d <- as.numeric(raw_data)
    vx <- d[1]; vy <- d[2]; vz <- d[3]
    wx <- d[4]; wy <- d[5]; wz <- d[6]
    
    v_norm <- sqrt(vx^2 + vy^2 + vz^2)
    w_norm <- sqrt(wx^2 + wy^2 + wz^2)
    
    # These time-based features are hardcoded in Python for single swing prediction
    # This implies the input raw_data is not a sequence to derive these from.
    return(data.frame(
      max_v = v_norm,
      mean_v = v_norm, # Assuming snapshot, so max and mean are the same
      max_w = w_norm,
      accel_time = 0.15, # Hardcoded as in Python
      decel_time = 0.35, # Hardcoded
      v_peak_time = 0.18, # Hardcoded
      w_integral = w_norm * 0.01 # Hardcoded rule from Python
    ))
  }, error = function(e) {
    message(paste("Input data error for single swing:", e$message))
    # Return a data frame with 0s, matching the feature column names used in training
    feature_cols <- c('max_v','mean_v','max_w','accel_time','decel_time','v_peak_time','w_integral')
    empty_features <- setNames(data.frame(matrix(0.0, ncol = length(feature_cols), nrow = 1)), feature_cols)
    return(empty_features)
  })
}

# --- Function for multi-target prediction on a new swing ---
predict_new_swing <- function(raw_data, models_list, scaler) {
  results <- list()
  target_cols_original_names <- c( # For consistent output keys
    'Swing Path Accuracy',
    'Swing Speed Smoothness',
    'Wrist Rotation Timing Accuracy',
    'Hit Timing Accuracy',
    'Ball Contact Position Accuracy'
  )
  target_cols_r_names <- make.names(target_cols_original_names)


  tryCatch({
    features_df <- extract_single_swing_features(raw_data)
    
    # Ensure column order matches what scaler expects (if it matters for predict.preProcess)
    # predict.preProcess should handle it by name, but good practice:
    # features_df <- features_df[, scaler$dimNames[[1]]] # Not directly available, 
                                                       # preProcess stores names it was trained on.
                                                       # For simple scaling, order is usually fine if names match.

    scaled_features_df <- predict(scaler, features_df)
    
    for (i in 1:length(target_cols_r_names)) {
      target_r_name <- target_cols_r_names[i]
      original_target_name <- target_cols_original_names[i]
      
      model <- models_list[[target_r_name]]
      if (!is.null(model)) {
        prediction <- predict(model, scaled_features_df)
        # Ensure prediction is a single numeric value
        prediction_value <- ifelse(length(prediction) > 0, prediction[1], 0) 
        results[[original_target_name]] <- max(0.0, min(5.0, round(prediction_value, 2)))
      } else {
        message(paste("Model for", target_r_name, "not found."))
        results[[original_target_name]] <- 0.0
      }
    }
    return(results)
    
  }, error = function(e) {
    message(paste("Prediction failed:", e$message))
    # Return default 0.0 scores
    default_results <- setNames(as.list(rep(0.0, length(target_cols_original_names))), target_cols_original_names)
    return(default_results)
  })
}

# --- Main execution block ---
main <- function() {
  message("=== Badminton Swing Analysis System (R Version) ===")
  message("Loading data...")
  full_data <- load_and_process_data()
  
  if (nrow(full_data) > 0) {
    message(paste("Loaded", nrow(full_data), "swings"))
    message("Training models...")
    
    # train_models returns a list with 'models' and 'scaler'
    training_artifacts <- train_models(full_data) 
    trained_models_list <- training_artifacts$models
    trained_scaler <- training_artifacts$scaler
    
    # Input test data (example raw sensor readings for a single moment)
    test_swings <- list(
      c(-5.946, 1.15, 8.466, 0.378, 0.058, -1.066),
      c(-5.726, 1.148, 8.408, 0.318, 0.004, -1.066)
    )
    
    message("\nReal-time Evaluation:")
    for (i in 1:length(test_swings)) {
      swing_data <- test_swings[[i]]
      result <- predict_new_swing(swing_data, trained_models_list, trained_scaler)
      message(paste("Swing", i, "Results:"))
      for (k in names(result)) {
        message(paste0("- ", k, ": ", result[[k]], "/5"))
      }
    }
  } else {
    message("Error: No valid data loaded")
  }
}

# Run the main function
if (interactive()) { # only run if in an interactive R session, or source the file to run.
  tryCatch({
    main()
  }, error = function(e) {
    message(paste("System Error:", e$message))
    print(sys.calls()) # Print call stack for debugging
  })
}