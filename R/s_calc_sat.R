##' @export

s_calc_sat <- function(df_std,
                       df_sat,
                       sat.rate.units = NULL,
                       sat.sub.conc.units = NULL,
                       km = NULL,
                       vmax = NULL,
                       act.time.units = NULL,
                       act.spec.units = NULL,
                       std.conc.units = NULL,
                       std.spec.units = NULL,
                       ...) {


  ### Run function that creates standard curve object
  std_obj <- s_calc_std(df_std,
                        std.conc.units,
                        std.spec.units,
                        ...)

  ### Run function that creates activity object
  act_obj <- s_calc_act(df_sat,
                        act.time.units,
                        act.spec.units,
                        df_std = df_std,
                        ...)

  ### Convert spec to conc. of standard and add to df_sat dataframe
  lm.intercept <- coef(std_obj$s_std_lm_fit)[1]
  lm.slope <- coef(std_obj$s_std_lm_fit)[2]
  act_obj$s_act_data$spec.to.std <- (act_obj$s_act_data$spec - lm.intercept)/lm.slope

  ### Create new dataframe containing calculated activities based on standard curve coefs
  df_sat_activity <- act_obj$s_act_data %>%
    dplyr::group_by(sub.conc, replicate) %>%
    tidyr::nest() %>%
    dplyr::mutate(activity = purrr::map_dbl(data, function(df) coef(lm(spec.to.std ~ time, data = df))[2])) %>%
    dplyr::group_by(sub.conc) %>%
    dplyr::mutate(activity.m = mean(activity), activity.sd = sd(activity))

  ### Assign starting values to predict km and vmax
  max.activity.m <- max(df_sat_activity$activity.m)
  median.conc <- median(df_sat_activity$sub.conc)

  mm_form <- formula(activity.m ~ (vmax * sub.conc) /
                       (km + sub.conc))

  ### If km and vmax arguments are NULL, predict km and vmax values
  if(is.null(km) | is.null(vmax)) {

    mm_fit <- nls2::nls2(formula = mm_form, data = df_sat_activity,
                         start = list(vmax = max.activity.m, km = median.conc))

  } else {

    ### Else rely on user defined km and vmax
    mm_fit <- nls2::nls2(formula = mm_form, data = df_sat_activity,
                         start = list(vmax = vmax, km = km))

  }

  ### Create a 1-column data frame with a grid of points to predict
  min.sub.conc <- min(df_sat_activity$sub.conc)
  max.sub.conc <- max(df_sat_activity$sub.conc)
  pred_grid <- data.frame(sub.conc = min.sub.conc:max.sub.conc)

  ### Put the predicted values into a data frame, paired with the values at which they were predicted
  predictions <- predict(mm_fit, newdata = pred_grid)

  pred_df <- data.frame(sub.conc = pred_grid$sub.conc, activity.m = predictions)

  ### Create vector of units
  units <- c("sat.rate.units" = sat.rate.units,
             "sat.sub.conc.units" = sat.sub.conc.units)


  out_list <- list(s_sat_activity_data = df_sat_activity,
                   s_sat_units = units,
                   s_sat_mm_fit = mm_fit,
                   s_sat_pred_act = pred_df,
                   s_std_obj = std_obj,
                   s_act_obj = act_obj,
                   ...)

  class(out_list) <- c("ezmmek_s_sat", "list")

  out_list

}
