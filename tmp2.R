lizard_OISST <- rast("./inst/extdata/lizard_OISST.tif")

lizard_OISST_df <- lizard_OISST |> as.data.frame(xy=TRUE, wide=FALSE, time=TRUE)

lizard_OISST_df_annual <- lizard_OISST_df |>
  mutate(time=as.Date(time), year=year(time), month=month(time)) |>
  group_by(year, month) |>
  summarise(sst=mean(values), month=mean(month)) |>
  filter(year >= 1985) |>
  filter(year <=2012)

#tmp <- lm(year ~ sst, data=lizard_OISST_df_annual |> filter(month==1))

lizard_OISST_predict_1998 <- lizard_OISST |> calculate_monthly_mean(return="predict", midpoint = 1998.5) |>
  as.data.frame(xy=FALSE, wide=FALSE, time=FALSE) |>
  mutate(month = seq(1:12))
lizard_OISST_predict <- lizard_OISST |> calculate_monthly_mean(return="predict", midpoint = 1988.2857)
  as.data.frame(xy=FALSE, wide=FALSE, time=FALSE) |>
  mutate(month = seq(1:12))
lizard_OISST_slope <- lizard_OISST |> calculate_monthly_mean(return="slope")
lizard_OISST_intercept <- lizard_OISST |> calculate_monthly_mean(return="intercept")



# Prepare the data with slope and intercept for each month
plot_data <- lizard_OISST_df_annual |>
  dplyr::mutate(
    slope = as.numeric(lizard_OISST_slope[[month]][1]),
    intercept = as.numeric(lizard_OISST_intercept[[month]][1])
  )

ggplot() +
  theme_bw() +
  geom_point(data = lizard_OISST_df_annual, aes(year, sst), alpha = 0.2) +
  geom_point(data = lizard_OISST_predict_1998, aes(1998.5, values), color="red", shape=8, size=3) +
  geom_point(data = lizard_OISST_predict, aes(1988.2857, values), color="darkred", shape=8, size=3) +
  geom_text(data = lizard_OISST_predict_1998, aes(1998.5, values + 0.2, label="1998.5"), color="red", size=3) +
  geom_text(data = lizard_OISST_predict, aes(1988.2857, values + 0.1, label="1988.2857"), color="darkred", size=3) +
  geom_abline(data = plot_data, aes(slope = slope, intercept = intercept),
              color = "black", linewidth = 0.75, alpha = 0.4) +
  facet_wrap(~month, ncol = 3, scales = "free") +
  scale_x_continuous(limits=c(1985, 2012), expand = c(0,0)) +

  # Horizontal lines (hline) stopping at intercepts
  geom_segment(data = lizard_OISST_predict_1998,
               aes(x = 1985, xend = 1998.5,
                   y = values, yend = values),
               color = "red") +
  geom_segment(data = lizard_OISST_predict,
               aes(x = 1985, xend = 1988.2857,
                   y = values, yend = values),
               color = "darkred") +

  # Vertical lines (vline) stopping at intercepts
  geom_segment(data = lizard_OISST_predict_1998,
               aes(x = 1998.5, xend = 1998.5,
                   y = -Inf, yend = values),
               color = "red") +
  geom_segment(data = lizard_OISST_predict,
               aes(x = 1988.2857, xend = 1988.2857,
                   y = -Inf, yend = values),
               color = "darkred")
