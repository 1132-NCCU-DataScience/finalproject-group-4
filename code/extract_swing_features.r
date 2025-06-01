library(readxl)
library(dplyr)
library(purrr)
library(stringr)
library(caret)
library(randomForest)
library(Metrics)
library(pracma) # For trapz function


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