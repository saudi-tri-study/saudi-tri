# ==============================================================================
# KSA LABOUR MARKET TRANSITION RISKS
# ==============================================================================

rm(list=ls())


libraries <- c(
  "ggplot2", "dplyr", "openxlsx", "grid", "tidyverse",
  "haven", "sf", "readxl", "weights", "patchwork", "here"
)

load_libraries <- function(libraries) {
  for (lib in libraries) {
    if (!require(lib, character.only = TRUE)) {
      install.packages(lib, dependencies = TRUE)
      library(lib, character.only = TRUE)
    }
  }
}

load_libraries(libraries)

'%ni%' <- Negate("%in%")


# ==============================================================================
# PATHS
# ==============================================================================
# Every path below is resolved from the project root by here::here(), which
# finds the root via saudi-tri.Rproj. The script therefore runs unchanged on
# any machine and from any working directory inside the project - no setwd().

dir.create(here::here("outputs", "figures"), recursive = TRUE, showWarnings = FALSE)
dir.create(here::here("outputs", "tables"),  recursive = TRUE, showWarnings = FALSE)

# Read Saudi employment data
emp_data <- read_dta(here::here("Data", "Saudi gosi 2018-22.dta"))

# Frequency Weighting variable is "numberofemployees"

# Filter years 2019, 2022
unique(emp_data$year)
emp_data <- filter(emp_data, year %in% c("2019-12-31", "2022-12-31"))

# Missing sectors, occupations, regions
length(emp_data$ISCO3[is.na(emp_data$ISCO3)==T | emp_data$ISCO3==0]) # 20824 observations
sum(emp_data$numberofemployees[is.na(emp_data$ISCO3)==T | emp_data$ISCO3==0], na.rm=T)

length(emp_data$economicactivity_en[emp_data$economicactivity_en==""]) # 89850 observations
sum(emp_data$numberofemployees[emp_data$economicactivity_en==""], na.rm=T)

length(emp_data$region_en[emp_data$region_en==""]) # 49552 observations
sum(emp_data$numberofemployees[emp_data$region_en==""], na.rm=T)

sum(emp_data$numberofemployees[is.na(emp_data$ISCO3) | emp_data$ISCO3==0 |
                                 emp_data$economicactivity_en=="" |
                                 emp_data$region_en==""], na.rm=T)


# ==============================================================================
# INDEX SUB-COMPONENTS
# ==============================================================================

# --- sector emission intensity (IMF) ------------------------------------------
# Sectors from IMF emission intensity of GVA table (Climate dashboard. USE most recent available year (2018))
emintens <- read.xlsx(here::here("Data", "saudi_emission_intensity_and_greenjob_potential.xlsx"),
                      sheet = "Emission intensity SAUDI", cols = c(12,37))

# Average over multiple-entry sectors (to match KSA labor data granularity)
emintens <- emintens %>% group_by(economicactivity_en) %>% summarise(emintens = mean(y2018))

# logs, and normalization
emintens$log_emintens <- log(emintens$emintens)

emintens$sector.score <- (emintens$log_emintens - min(emintens$log_emintens)) /
                            (max(emintens$log_emintens)-min(emintens$log_emintens))

# Emp data before any merges
# Before merges
before <- emp_data %>% group_by(year) %>% summarise(total_emp = sum(numberofemployees, na.rm=T))


# Merge sector scores with KSA labor data
setdiff(unique(emintens$economicactivity_en), unique(emp_data$economicactivity_en)) # All names match

emp_data <- merge(emp_data, emintens, by=c("economicactivity_en"))

# add epsilon for the 0-sector
emp_data$sector.score[emp_data$economicactivity_en=="Real estate activities"] <- 0.001

# --- occupation green potential (Rutzer et al.) -------------------------------
# Green job potential scores from Rutzer et al (2018); Lobsiger & Rutzer (2021) [ISCO3 level to match KSA labor data]
greenjobs <- read.xlsx(here::here("Data", "saudi_emission_intensity_and_greenjob_potential.xlsx"),
                       sheet = "Green potential scores (ISCO)", cols = c(4,5,6), startRow = 4)


greenjobs <- filter(greenjobs, !is.na(ISCO3))


colnames(greenjobs)[3] <- "occupation.score"

# Merge occupation scores with KSA labor data
emp_data <- merge(emp_data, greenjobs, by=c("ISCO3"))

# --- regional unemployment (Saudi LFS) ----------------------------------------
# Regional unemployment rates from SAUDI LFS 2019q4 and 2022q4 (by gender)

# Normalization within year, and gender. Make use of gender-specific unemployment rates.
unemp <- read.xlsx(here::here("Data", "saudi_unemp_19_22_q4_orig.xlsx"), sheet = "combined")

# The workbook ships a pre-computed unemp.score alongside the raw rate. Rebuild it
# here so all three pillars are constructed in code rather than one arriving
# already normalised, then assert the two agree before using ours. The rescaling
# is min-max within each year x gender group (13 regions per group).
unemp <- unemp %>%
  dplyr::group_by(year, gender) %>%
  dplyr::mutate(unemp.score_recomputed =
                  (rate - min(rate, na.rm = TRUE)) /
                  (max(rate, na.rm = TRUE) - min(rate, na.rm = TRUE))) %>%
  dplyr::ungroup() %>%
  as.data.frame()

stopifnot(
  "recomputed unemp.score does not match the workbook" =
    isTRUE(all.equal(unemp$unemp.score_recomputed, unemp$unemp.score, tolerance = 1e-12))
)
unemp$unemp.score <- unemp$unemp.score_recomputed
unemp$unemp.score_recomputed <- NULL

# Match years
emp_data$year[emp_data$year=="2022-12-31"] <- "2022"
emp_data$year[emp_data$year=="2019-12-31"] <- "2019"

# Match region names
emp_data$region_en[emp_data$region_en=="Northern Borders"] <- "Al Hudud ash Shamaliyah"
emp_data$region_en[emp_data$region_en=="Eastern Province"] <- "Ash Sharqiyah"
emp_data$region_en[emp_data$region_en=="Qassim"] <- "Al Quassim"
emp_data$region_en[emp_data$region_en=="Hail"] <- "Ha'il"
emp_data$region_en[emp_data$region_en=="Riyadh"] <- "Ar Riyad"
emp_data$region_en[emp_data$region_en=="Al-Baha"] <- "Al Bahah"
emp_data$region_en[emp_data$region_en=="Asir"] <- "`Asir"
emp_data$region_en[emp_data$region_en=="Al-Jouf"] <- "Al Jawf"
emp_data$region_en[emp_data$region_en=="Madinah"] <- "Al Madinah"
emp_data$region_en[emp_data$region_en=="Jazan"] <- "Jizan"

# Names match check
setdiff(unique(emp_data$region_en), unique(unemp$region_en))
setdiff(unique(unemp$region_en), unique(emp_data$region_en))

# Merge regional unemployment rate scores by region, gender and year
emp_data <- merge(emp_data, unemp, by=c("year","gender", "region_en"))


# Add epsilon to unemployment rates
emp_data$unemp.score[emp_data$unemp.score==0] <- 0.001

# --- TRI construction ---------------------------------------------------------
# INDEX generation
emp_data$index.score <- emp_data$sector.score^(1/3)*emp_data$unemp.score^(1/3)*
                        (1-emp_data$occupation.score)^(1/3)

# ADD BINNED INDEX VARIABLE
emp_data <- emp_data %>% mutate(index_binned = cut(index.score,
                                                   breaks = c(0,0.1,0.2,0.3,0.4,0.5,0.6,0.7,0.8,0.9,1.0)))


# ==============================================================================
# MAP SHAPEFILES
# Saudi Arabia region maps from homaily/Saudi-Arabia-Regions-Cities-and-Districts.
# Not redistributed with this repository - that source is GPL-2.0 licensed - so the
# file is fetched on first run from a pinned commit and checksummed, which gives
# every machine byte-identical geometry.
# name_en is remapped to the Natural-Earth-style names that emp_data$name uses.
# ==============================================================================
geo_path <- here::here("Data", "saudi_geo", "regions.geojson")
geo_url  <- paste0("https://raw.githubusercontent.com/homaily/",
                   "Saudi-Arabia-Regions-Cities-and-Districts/",
                   "7e322945fa9f6d696a54ba3e9038e0e750e9692d/geojson/regions.geojson")
geo_md5  <- "c0cb83e693f6bc55cbe277e6961c50d1"

if (!file.exists(geo_path)) {
  dir.create(dirname(geo_path), recursive = TRUE, showWarnings = FALSE)
  message("Downloading region maps (6 MB) from ", geo_url)
  utils::download.file(geo_url, geo_path, mode = "wb", quiet = TRUE)
}
if (unname(tools::md5sum(geo_path)) != geo_md5) {
  stop("regions.geojson does not match the expected checksum (", geo_md5, "). ",
       "Delete the file and re-run to fetch a clean copy.")
}

saudi <- sf::st_read(geo_path, quiet = TRUE) %>%
  sf::st_collection_extract("POLYGON") %>%
  dplyr::mutate(name = dplyr::recode(name_en,
    "Riyadh"            = "Ar Riyad",
    "Makkah"            = "Makkah",
    "Madinah"           = "Al Madinah",
    "Qassim"            = "Al Quassim",
    "Eastern Province"  = "Ash Sharqiyah",
    "Asir"              = "`Asir",
    "Tabuk"             = "Tabuk",
    "Hail"              = "Ha'il",
    "Northern Borders"  = "Al Hudud ash Shamaliyah",
    "Jazan"             = "Jizan",
    "Najran"            = "Najran",
    "Bahah"             = "Al Bahah",
    "Jawf"              = "Al Jawf"
  ))

# match region varnames
emp_data <- rename(emp_data, name = region_en)


# ==============================================================================
# FIGURE 4 in manuscript - TRI by Saudi Administrative Regions (2022)
# RISK MAP plot for KSA 2022
# ==============================================================================
df_mean_reg <- emp_data %>% filter(year=="2022") %>%
  group_by(name) %>% summarise(mean_index = mean(index.score, na.rm=T))

df_saudi_regions_tot <- merge(saudi, df_mean_reg, by="name")

# Plot the map
# Per-region label positions: place inside the region, nudge Makkah north,
# force Jizan to its geometric centroid (point_on_surface puts it at the southern boundary)
maprisk_labels <- suppressWarnings(sf::st_point_on_surface(df_saudi_regions_tot)) %>%
  sf::st_coordinates() %>%
  as.data.frame() %>%
  dplyr::bind_cols(sf::st_drop_geometry(df_saudi_regions_tot)[, c("name", "mean_index")]) %>%
  dplyr::mutate(
    X = dplyr::case_when(name == "Jizan" ~ 42.75, TRUE ~ X),
    Y = dplyr::case_when(
      name == "Jizan"  ~ 17.30,
      name == "Makkah" ~ Y + 2.5,
      TRUE             ~ Y
    )
  )

maprisk <- ggplot() +
  geom_sf(data = df_saudi_regions_tot , aes(fill = mean_index), color = "black") +
  geom_text(data = maprisk_labels,
            aes(x = X, y = Y, label = sprintf("%.2f", mean_index)),
            size = 2.0, fontface = "bold", color = "black") +
  scale_fill_viridis_c(option = "E", direction = -1, name = "Average index score",
                       limits = c(0.02, 0.62), alpha = 0.8 ) +
  theme_void(base_size = 10) +
  theme(    legend.position = c(0.85,0.8), legend.text = element_text(size=7),
            legend.title = element_text(size=7, face = "bold"),
            legend.background = element_rect(fill="white",
                                             linewidth =0.5, linetype="solid",
                                             colour ="black"))
maprisk

# --- save ---------------------------------------------------------------------
# SAVE PLOT as PNG
ggsave(
  here::here("outputs", "figures", "02_tri_map_2022.png"), maprisk,
  width = 5,
  height = 5,
  dpi = 600
)


# ==============================================================================
# FIGURE 3 in manuscript - Transition Risk Index Distribution in Saudi Arabia: 2019 & 2022
# Transition risk Index Distribution KSA 2019, 2022
# ==============================================================================
avg_2019 <- weighted.mean(emp_data$index.score[emp_data$year==2019],
                          emp_data$numberofemployees[emp_data$year==2019], na.rm = T)
avg_2022 <- weighted.mean(emp_data$index.score[emp_data$year==2022],
                          emp_data$numberofemployees[emp_data$year==2022], na.rm = T)

index_barchart <- emp_data %>% group_by(year,index_binned) %>%
  dplyr::summarise(emp_count = sum(numberofemployees, na.rm = T)) %>% na.omit()

emp_countyear <- emp_data %>% filter(!is.na(index_binned)) %>% group_by(year) %>%
  dplyr::summarise(emp_tot = sum(numberofemployees, na.rm = T)) %>% na.omit()

index_barchart <- merge(index_barchart, emp_countyear, by="year")

index_barchart$empshare <- index_barchart$emp_count / index_barchart$emp_tot * 100

index_bars <- ggplot(index_barchart, aes(x = index_binned, y = empshare, fill = year)) +
  geom_bar(stat = "identity", position = position_dodge(width = 0.8),
           width = 0.7) +
  xlab("Transition Risk Index") +
  ylab("Share of employees (%)") +
  theme_classic(base_size = 13) +
  theme(
    legend.position = c(0.5, 0.9),
    legend.direction = "horizontal",
    legend.text = element_text(size = 10),
    legend.title = element_text(size = 10, face = "bold"),
    legend.key.size = unit(0.4, "cm"),
    legend.background = element_rect(fill = "white", linewidth = 0.2, colour = "grey50"),
    axis.title.x = element_text(margin = margin(t = 10)),
    axis.title.y = element_text(margin = margin(r = 10))
  ) +
  scale_fill_manual(values = c("#7BB8CA", "navy"), name = "Year") +
  annotate("text", x = 10.5, y = 43,
           label = sprintf("Average TRI 2019: %.2f", avg_2019),
           color = "#7BB8CA", fontface = "bold", size = 3.5, hjust = 1) +
  annotate("text", x = 10.5, y = 40,
           label = sprintf("Average TRI 2022: %.2f", avg_2022),
           color = "navy", fontface = "bold", size = 3.5, hjust = 1)
index_bars
ggsave(here::here("outputs", "figures", "01_index_baseline.png"), plot = index_bars,
       width = 8, height = 3.8, dpi = 300, bg = "white")


# ==============================================================================
# FIGURES A1, A2, A3 in manuscript (bar charts) - TRI distribution under
# sector-heavy / region-heavy / occupation-heavy weightings. Appendix B.
# "region-heavy" puts the extra weight on unemp.score, the regional labour-market
# frictions pillar - the manuscript's name for it, used here too.
# --- Alternative-weight variants of index_bars (identical layout) -------------
# ==============================================================================
weight_variants <- list(
  list(label = "sector_heavy", w_s = 0.5,  w_u = 0.25, w_o = 0.25,
       file = "04_index_sector_heavy.png"),   # Figure A1
  list(label = "region_heavy", w_s = 0.25, w_u = 0.5,  w_o = 0.25,
       file = "05_index_region_heavy.png"),   # Figure A2
  list(label = "occ_heavy",    w_s = 0.25, w_u = 0.25, w_o = 0.5,
       file = "06_index_occ_heavy.png")       # Figure A3
)

for (wv in weight_variants) {
  tmp <- emp_data
  tmp$index.score <- tmp$sector.score^wv$w_s *
                     tmp$unemp.score^wv$w_u *
                     (1 - tmp$occupation.score)^wv$w_o
  tmp <- tmp %>% mutate(index_binned = cut(index.score,
                                           breaks = c(0,0.1,0.2,0.3,0.4,0.5,0.6,0.7,0.8,0.9,1.0)))

  avg_2019_v <- weighted.mean(tmp$index.score[tmp$year==2019],
                              tmp$numberofemployees[tmp$year==2019], na.rm = T)
  avg_2022_v <- weighted.mean(tmp$index.score[tmp$year==2022],
                              tmp$numberofemployees[tmp$year==2022], na.rm = T)

  ibc_v <- tmp %>% group_by(year, index_binned) %>%
    dplyr::summarise(emp_count = sum(numberofemployees, na.rm = T)) %>% na.omit()
  emp_countyear_v <- tmp %>% filter(!is.na(index_binned)) %>% group_by(year) %>%
    dplyr::summarise(emp_tot = sum(numberofemployees, na.rm = T)) %>% na.omit()
  ibc_v <- merge(ibc_v, emp_countyear_v, by = "year")
  ibc_v$empshare <- ibc_v$emp_count / ibc_v$emp_tot * 100

  index_bars_v <- ggplot(ibc_v, aes(x = index_binned, y = empshare, fill = year)) +
    geom_bar(stat = "identity", position = position_dodge(width = 0.8),
             width = 0.7) +
    xlab("Transition Risk Index") +
    ylab("Share of employees (%)") +
    theme_classic(base_size = 13) +
    theme(
      legend.position = c(0.5, 0.9),
      legend.direction = "horizontal",
      legend.text = element_text(size = 10),
      legend.title = element_text(size = 10, face = "bold"),
      legend.key.size = unit(0.4, "cm"),
      legend.background = element_rect(fill = "white", linewidth = 0.2, colour = "grey50"),
      axis.title.x = element_text(margin = margin(t = 10)),
      axis.title.y = element_text(margin = margin(r = 10))
    ) +
    scale_fill_manual(values = c("#7BB8CA", "navy"), name = "Year") +
    coord_cartesian(ylim = c(0, max(ibc_v$empshare, na.rm = TRUE) * 1.3)) +
    annotation_custom(
      grob = textGrob(sprintf("Average TRI 2019: %.2f", avg_2019_v),
                      x = unit(0.99, "npc"), y = unit(0.924, "npc"),
                      hjust = 1, vjust = 0.5,
                      gp = gpar(col = "#7BB8CA", fontface = "bold",
                                fontsize = 3.5 * ggplot2::.pt))
    ) +
    annotation_custom(
      grob = textGrob(sprintf("Average TRI 2022: %.2f", avg_2022_v),
                      x = unit(0.99, "npc"), y = unit(0.863, "npc"),
                      hjust = 1, vjust = 0.5,
                      gp = gpar(col = "navy", fontface = "bold",
                                fontsize = 3.5 * ggplot2::.pt))
    )

  ggsave(here::here("outputs", "figures", wv$file), plot = index_bars_v,
         width = 8, height = 3.8, dpi = 300, bg = "white")
}


# ==============================================================================
# FIGURE 5 in manuscript - TRI Distribution by Jobs, Region, and Gender in Saudi Arabia
# GENDER DYNAMICS (Combined figure including INDEX barchart 2022, map green transition risk of employment by region and gender)
# ==============================================================================
weighted.mean(emp_data$index.score[emp_data$year==2022 & emp_data$gender=="Female"],
              emp_data$numberofemployees[emp_data$year==2022 & emp_data$gender=="Female"],
              na.rm = T)
weighted.mean(emp_data$index.score[emp_data$year==2022 & emp_data$gender=="Male"],
              emp_data$numberofemployees[emp_data$year==2022 & emp_data$gender=="Male"],
              na.rm = T)

index_barchart_gender <- emp_data %>% filter(year==2022) %>% group_by(gender,index_binned) %>%
  dplyr::summarise(emp_count = sum(numberofemployees, na.rm = T)) %>% na.omit()

emp_countgender <- emp_data %>% filter(!is.na(index_binned), year==2022) %>%
  group_by(gender) %>%
  dplyr::summarise(emp_tot = sum(numberofemployees, na.rm = T)) %>% na.omit()

index_barchart_gender <- merge(index_barchart_gender, emp_countgender, by="gender")
index_barchart_gender$empshare <- index_barchart_gender$emp_count / index_barchart_gender$emp_tot * 100

# --- map by region and gender -------------------------------------------------
# Risk MAP by region and gender 2022

# RISK MAP plot for KSA 2022
df_mean_reg_gender <- emp_data %>% filter(year=="2022") %>%
  group_by(name, gender) %>% summarise(mean_index = mean(index.score, na.rm=T))

df_saudi_regions_gender <- merge(saudi, df_mean_reg_gender, by="name")

# Plot the map (live from homaily geometry; matches main map styling)
maprisk_gender <- ggplot() +
  geom_sf(data = df_saudi_regions_gender , aes(fill = mean_index), color = "black") +
  scale_fill_viridis_c(option = "E", direction = -1, name = "Average index score",
                       limits = c(0.02, 0.62), alpha = 0.8 ) +
  facet_wrap(~gender) +
  theme_void(base_size = 12) +
  theme(    strip.text = element_text(size = 12, face = "bold"),
            legend.position = "right",
            legend.text = element_text(size = 9),
            legend.title = element_text(size = 9, face = "bold"),
            legend.background = element_rect(fill = "white",
                                             linewidth = 0.5, linetype = "solid",
                                             colour = "black"))
maprisk_gender

# --- bar chart ----------------------------------------------------------------
# Bar chart
index_bars2 <- ggplot(index_barchart_gender, aes(x = index_binned, y = empshare, fill = gender)) +
  geom_bar(stat = "identity", position = position_dodge(width = 0.8),
           width = 0.7, color = "grey30", linewidth = 0.2) +
  xlab("Transition Risk Index") +
  ylab("Share of employees (%)") +
  ggtitle("Transition Risk Index Distribution by Gender in Saudi Arabia (2022)") +
  theme_classic(base_size = 14) +
  theme(
    plot.title = element_text(size = 13, face = "bold", hjust = 0),
    legend.position = c(0.5, 0.95),
    legend.direction = "horizontal",
    legend.text = element_text(size = 10),
    legend.title = element_text(size = 10, face = "bold"),
    legend.key.size = unit(0.4, "cm"),
    legend.background = element_rect(fill = "white", linewidth = 0.2, colour = "grey50"),
    axis.title.x = element_text(margin = margin(t = 10)),
    axis.title.y = element_text(margin = margin(r = 10))
  ) +
  scale_fill_manual(values = c("red", "navy"), name = "Gender") +
  annotate("text", x = 10, y = 50,
           label = "Average score Female: 0.17",
           color = "red", fontface = "bold", size = 3.5, hjust = 1) +
  annotate("text", x = 10, y = 48,
           label = "Average score Male: 0.23",
           color = "navy", fontface = "bold", size = 3.5, hjust = 1)

# Map title as a grob
map_title <- wrap_elements(
  textGrob("Transition Risk Index by Gender in Saudi Arabia (2022)",
           x = 0, hjust = 0,
           gp = gpar(fontsize = 13, fontface = "bold"))
)

# Combine: bar chart on top, title row, faceted gender map drawn live from homaily geometry
combined <- index_bars2 / map_title / maprisk_gender +
  plot_layout(heights = c(1, 0.05, 0.95))

ggsave(here::here("outputs", "figures", "03_TRI_index_map_gender.png"), combined,
       width = 12, height = 10, dpi = 600, bg = "white")


# Emp data after merges
after <- emp_data %>% group_by(year) %>% summarise(total_emp = sum(numberofemployees, na.rm=T))

before
after


# ==============================================================================
# ISCO-08 LABEL LOOKUPS
# ==============================================================================

# ISCO labels data

# In emp_data, mutate ISCO2 equals first two characters of ISCO3
emp_data <- emp_data %>%
  mutate(
    ISCO2 = as.double(substr(ISCO3, 1, 2)),
  )

isco <- read_xlsx(
  here::here("Data", "ISCO.xlsx"),
  sheet = "ISCO_08")


isco_1 <- isco %>%
  select(major, major_label) %>%
  distinct() %>%
  rename(ISCO1 = major, ISCO1_label = major_label) %>%
  mutate(ISCO1 = as.double(ISCO1))

isco_2 <- isco %>%
  select(sub_major, sub_major_label) %>%
  distinct() %>%
  rename(ISCO2 = sub_major, ISCO2_label = sub_major_label) %>%
  mutate(ISCO2 = as.double(ISCO2))

isco_3 <- isco %>%
  select(minor, minor_label) %>%
  distinct() %>%
  rename(ISCO3 = minor, ISCO3_label = minor_label) %>%
  mutate(ISCO3 = as.double(ISCO3))

isco_4 <- isco %>%
  select(unit, description) %>%
  distinct() %>%
  rename(ISCO4 = unit, ISCO4_label = description) %>%
  mutate(ISCO4 = as.double(ISCO4))

# Join codes to gosi_2
emp_data <- emp_data %>%
  left_join(isco_1, by = "ISCO1") %>%
  left_join(isco_2, by = "ISCO2") %>%
  left_join(isco_3, by = "ISCO3") %>%
  left_join(isco_4, by = "ISCO4")


# ==============================================================================
# FOOTNOTE 7 in manuscript - gender TRI significance tests
# ==============================================================================

# --- Weighted t-test: Overall TRI (index.score) by gender, 2022 ---------------

cat("\n======= GENDER TRI SIGNIFICANCE TESTS (2022) =======\n\n")

# Filter to 2022
d22 <- emp_data %>% filter(year == "2022")

cat("--- Overall TRI (index.score) ---\n")
tri_ttest <- wtd.t.test(
  x      = d22$index.score[d22$gender == "Female"],
  y      = d22$index.score[d22$gender == "Male"],
  weight  = d22$numberofemployees[d22$gender == "Female"],
  weighty = d22$numberofemployees[d22$gender == "Male"]
)
print(tri_ttest)

cat("\n--- Sector score (sector.score) ---\n")
sector_ttest <- wtd.t.test(
  x      = d22$sector.score[d22$gender == "Female"],
  y      = d22$sector.score[d22$gender == "Male"],
  weight  = d22$numberofemployees[d22$gender == "Female"],
  weighty = d22$numberofemployees[d22$gender == "Male"]
)
print(sector_ttest)

cat("\n--- Occupation green score (occupation.score) ---\n")
occ_ttest <- wtd.t.test(
  x      = d22$occupation.score[d22$gender == "Female"],
  y      = d22$occupation.score[d22$gender == "Male"],
  weight  = d22$numberofemployees[d22$gender == "Female"],
  weighty = d22$numberofemployees[d22$gender == "Male"]
)
print(occ_ttest)

cat("\n--- Regional unemployment score (unemp.score) ---\n")
unemp_ttest <- wtd.t.test(
  x      = d22$unemp.score[d22$gender == "Female"],
  y      = d22$unemp.score[d22$gender == "Male"],
  weight  = d22$numberofemployees[d22$gender == "Female"],
  weighty = d22$numberofemployees[d22$gender == "Male"]
)
print(unemp_ttest)

# --- Collect results into a tidy summary table --------------------------------
ttest_summary <- data.frame(
  Component      = c("Overall TRI", "Sector score", "Occupation (green potential)", "Unemployment score"),
  Female_mean    = round(c(tri_ttest$additional["Mean.x"],
                           sector_ttest$additional["Mean.x"],
                           occ_ttest$additional["Mean.x"],
                           unemp_ttest$additional["Mean.x"]), 4),
  Male_mean      = round(c(tri_ttest$additional["Mean.y"],
                           sector_ttest$additional["Mean.y"],
                           occ_ttest$additional["Mean.y"],
                           unemp_ttest$additional["Mean.y"]), 4),
  Difference     = round(c(tri_ttest$additional["Difference"],
                           sector_ttest$additional["Difference"],
                           occ_ttest$additional["Difference"],
                           unemp_ttest$additional["Difference"]), 4),
  t_statistic    = round(c(tri_ttest$coefficients["t.value"],
                           sector_ttest$coefficients["t.value"],
                           occ_ttest$coefficients["t.value"],
                           unemp_ttest$coefficients["t.value"]), 3),
  p_value        = c(tri_ttest$coefficients["p.value"],
                     sector_ttest$coefficients["p.value"],
                     occ_ttest$coefficients["p.value"],
                     unemp_ttest$coefficients["p.value"]),
  row.names = NULL
)

ttest_summary$Significance <- ifelse(ttest_summary$p_value < 0.001, "***",
                                     ifelse(ttest_summary$p_value < 0.01, "**",
                                            ifelse(ttest_summary$p_value < 0.05, "*",
                                                   ifelse(ttest_summary$p_value < 0.10, ".", ""))))

cat("\n--- Summary table ---\n")
print(ttest_summary)

# --- Repeat for 2019 (footnote 7 reports both years) --------------------------
cat("\n\n======= GENDER TRI SIGNIFICANCE TESTS (2019) =======\n\n")

d19 <- emp_data %>% filter(year == "2019")

cat("--- Overall TRI 2019 ---\n")
tri_ttest_19 <- wtd.t.test(
  x      = d19$index.score[d19$gender == "Female"],
  y      = d19$index.score[d19$gender == "Male"],
  weight  = d19$numberofemployees[d19$gender == "Female"],
  weighty = d19$numberofemployees[d19$gender == "Male"]
)
print(tri_ttest_19)

cat("\n--- Sector score 2019 ---\n")
sector_ttest_19 <- wtd.t.test(
  x      = d19$sector.score[d19$gender == "Female"],
  y      = d19$sector.score[d19$gender == "Male"],
  weight  = d19$numberofemployees[d19$gender == "Female"],
  weighty = d19$numberofemployees[d19$gender == "Male"]
)
print(sector_ttest_19)

cat("\n--- Occupation green score 2019 ---\n")
occ_ttest_19 <- wtd.t.test(
  x      = d19$occupation.score[d19$gender == "Female"],
  y      = d19$occupation.score[d19$gender == "Male"],
  weight  = d19$numberofemployees[d19$gender == "Female"],
  weighty = d19$numberofemployees[d19$gender == "Male"]
)
print(occ_ttest_19)

cat("\n--- Regional unemployment score 2019 ---\n")
unemp_ttest_19 <- wtd.t.test(
  x      = d19$unemp.score[d19$gender == "Female"],
  y      = d19$unemp.score[d19$gender == "Male"],
  weight  = d19$numberofemployees[d19$gender == "Female"],
  weighty = d19$numberofemployees[d19$gender == "Male"]
)
print(unemp_ttest_19)

# --- 2019 Summary table -------------------------------------------------------
ttest_summary_19 <- data.frame(
  Component      = c("Overall TRI", "Sector score", "Occupation (green potential)", "Unemployment score"),
  Female_mean    = round(c(tri_ttest_19$additional["Mean.x"],
                           sector_ttest_19$additional["Mean.x"],
                           occ_ttest_19$additional["Mean.x"],
                           unemp_ttest_19$additional["Mean.x"]), 4),
  Male_mean      = round(c(tri_ttest_19$additional["Mean.y"],
                           sector_ttest_19$additional["Mean.y"],
                           occ_ttest_19$additional["Mean.y"],
                           unemp_ttest_19$additional["Mean.y"]), 4),
  t_statistic    = round(c(tri_ttest_19$coefficients["t.value"],
                           sector_ttest_19$coefficients["t.value"],
                           occ_ttest_19$coefficients["t.value"],
                           unemp_ttest_19$coefficients["t.value"]), 3),
  row.names = NULL
)
cat("\n--- 2019 Summary table ---\n")
print(ttest_summary_19)

# --- Non-parametric robustness: Wilcoxon rank-sum (unweighted) ----------------
cat("\n--- Robustness: Wilcoxon rank-sum test (unweighted) on overall TRI, 2022 ---\n")
wilcox_tri <- wilcox.test(
  index.score ~ gender,
  data = d22,
  alternative = "two.sided"
)
print(wilcox_tri)


# ==============================================================================
# FOOTNOTE 1 in manuscript - arithmetic-mean TRI robustness check
# The current TRI uses geometric mean (equal exponent = 1/3 on each component):
#   index.score = sector.score^(1/3) * unemp.score^(1/3) * (1 - occupation.score)^(1/3)
# ==============================================================================
#
# An equal-weighted ARITHMETIC mean alternative:
#   TRI_ew = (1/3) * sector.score + (1/3) * unemp.score + (1/3) * (1 - occupation.score)

# --- Compute equal-weighted (arithmetic mean) TRI -----------------------------
emp_data <- emp_data %>%
  mutate(
    TRI_ew = (sector.score + unemp.score + (1 - occupation.score)) / 3
  )

# --- Weighted average equal-weighted TRI --------------------------------------
avg_ew_2019 <- with(subset(emp_data, year == 2019),
                    weighted.mean(TRI_ew, numberofemployees, na.rm = TRUE))
avg_ew_2022 <- with(subset(emp_data, year == 2022),
                    weighted.mean(TRI_ew, numberofemployees, na.rm = TRUE))


# --- Comparison print: geometric mean TRI vs equal-weighted arithmetic TRI ----
cat("\n======= GEOMETRIC vs EQUAL-WEIGHTED TRI COMPARISON =======\n")
cat(sprintf("Geometric mean TRI  - 2019: %.4f  |  2022: %.4f  |  Change: %.4f\n",
            avg_2019, avg_2022, avg_2022 - avg_2019))
cat(sprintf("Arithmetic mean TRI - 2019: %.4f  |  2022: %.4f  |  Change: %.4f\n",
            avg_ew_2019, avg_ew_2022, avg_ew_2022 - avg_ew_2019))


# ==============================================================================
# TABLE 2 in manuscript - Transition Risk Index Illustration
# "hold-two-constant, vary-one": three panels, each isolating one pillar of the TRI
#   Panel A: fix OCCUPATION + REGION, vary SECTOR      -> isolates sector.score
#   Panel B: fix OCCUPATION + SECTOR, vary REGION      -> isolates unemp.score
#   Panel C: fix SECTOR + REGION,     vary OCCUPATION  -> isolates (1 - occupation.score)
# ==============================================================================

# ---- 0) Short-label lookups (curated; fallback = first comma-clause, truncated) ------
sector_short <- c(
  "Mining and quarrying" = "Mining & quarrying",
  "Electricity, gas, steam and air conditioning supply" = "Electricity & gas",
  "Manufacturing" = "Manufacturing",
  "Construction" = "Construction",
  "Transportation and storage" = "Transport",
  "Administrative and support service activities" = "Admin. services",
  "Water supply; sewerage, waste management and remediation activities" = "Water & waste",
  "Professional, scientific and technical activities" = "Prof. services",
  "Wholesale and retail trade; repair of motor vehicles and motorcycles" = "Retail & trade",
  "Information and communication" = "Info & comms",
  "Other service activities" = "Other services",
  "Accommodation and food service activities" = "Accommodation & food",
  "Education" = "Education",
  "Public administration and defence; compulsory social security" = "Public admin.",
  "Human health and social work activities" = "Health & social",
  "Agriculture, forestry and fishing" = "Agriculture",
  "Financial and insurance activities" = "Finance & insurance",
  "Real estate activities" = "Real estate",
  "Arts, entertainment and recreation" = "Arts & recreation",
  "Activities of households as employers" = "Household services",
  "Activities of extraterritorial organizations and bodies" = "Extraterritorial"
)

region_short <- c(
  "Ash Sharqiyah" = "Eastern Prov.",
  "Ar Riyad"      = "Riyadh",
  "Al Madinah"    = "Madinah",
  "Makkah"        = "Mekkah",
  "`Asir"         = "Asir",
  "Al Quassim"    = "Qassim",
  "Ha'il"         = "Hail",
  "Al Bahah"      = "Al-Baha",
  "Al Jawf"       = "Al-Jouf",
  "Jizan"         = "Jazan",
  "Najran"        = "Najran",
  "Tabuk"         = "Tabuk",
  "Al Hudud ash Shamaliyah" = "North. Borders"
)

occupation_short <- c(
  "Physical and Engineering Science Technicians" = "Eng. Technicians",
  "Architects, Planners, Surveyors and Designers" = "Architects & Designers",
  "Blacksmiths, Toolmakers and Related Trades Workers" = "Blacksmiths & Toolmakers",
  "Other Health Associate Professionals" = "Health Associate Prof.",
  "Science and Engineering Professionals" = "Eng. Professionals",
  "Information and Communications Technology Professionals" = "ICT Professionals",
  "Information and Communications Technicians" = "ICT Technicians",
  "Engineering Professionals (excluding Electrotechnology)" = "Eng. Professionals (non-elec)",
  "Administrative and Specialized Secretaries" = "Admin. & Spec. Secretaries",
  "Sheet and Structural Metal Workers, Moulders and Welders, and Related Workers" = "Metal Workers & Welders",
  "Machinery Mechanics and Repairers" = "Machinery Mechanics",
  "Sales and Purchasing Agents and Brokers" = "Sales & Purchasing Agents",
  "Health Professionals" = "Health Professionals",
  "Health Associate Professionals" = "Health Associate Prof.",
  "Business and Administration Professionals" = "Business Prof.",
  "Business and Administration Associate Professionals" = "Business Associate Prof.",
  "Teaching Professionals" = "Teachers",
  "Legal, Social and Cultural Professionals" = "Legal/Social Prof.",
  "General and Keyboard Clerks" = "General Clerks",
  "Customer Services Clerks" = "Customer Service Clerks",
  "Numerical and Material Recording Clerks" = "Record Clerks",
  "Other Clerical Support Workers" = "Other Clerks",
  "Personal Service Workers" = "Personal Service",
  "Sales Workers" = "Sales Workers",
  "Personal Care Workers" = "Personal Care",
  "Protective Services Workers" = "Protective Services",
  "Building and Related Trades Workers (excluding Electricians)" = "Building Trades",
  "Metal, Machinery and Related Trades Workers" = "Metal/Machinery Trades",
  "Handicraft and Printing Workers" = "Handicraft & Printing",
  "Electrical and Electronic Trades Workers" = "Electrical Trades",
  "Food Processing, Wood Working, Garment and Other Craft and Related Trades Workers" = "Craft Trades",
  "Stationary Plant and Machine Operators" = "Plant Operators",
  "Assemblers" = "Assemblers",
  "Drivers and Mobile Plant Operators" = "Drivers & Plant Op.",
  "Cleaners and Helpers" = "Cleaners",
  "Labourers in Mining, Construction, Manufacturing and Transport" = "General Labourers",
  "Food Preparation Assistants" = "Food Prep. Assist.",
  "Subsistence Farmers, Fishers, Hunters and Gatherers" = "Subsistence Farmers",
  "Chief Executives, Senior Officials and Legislators" = "Chief Execs & Senior Officials",
  "Administrative and Commercial Managers" = "Admin. Managers",
  "Production and Specialised Services Managers" = "Production Managers",
  "Hospitality, Retail and Other Services Managers" = "Hospitality Managers"
)

shorten <- function(x, lookup, max_chars = 28) {
  out <- unname(lookup[x])
  miss <- is.na(out)
  if (any(miss)) {
    # fallback: take up to the first comma, then truncate with ellipsis if still too long
    fb <- sub(",.*", "", x[miss])
    fb <- ifelse(nchar(fb) > max_chars,
                 paste0(substr(fb, 1, max_chars - 1), "..."),
                 fb)
    out[miss] <- fb
  }
  out
}

# ---- 1) Configuration ---------------------------------------------------------------
illus_year        <- "2022"
illus_gender      <- "Male"
# Each panel is self-contained: it picks its own fixed dimensions and its own
# pivot cell (the middle bar). The three panels no longer share a single base.
#
# Panel A: vary SECTOR; fix occupation + region; pivot sector = Manufacturing
panelA_occ          <- "Machinery Mechanics and Repairers"
panelA_region       <- "Ash Sharqiyah"
panelA_pivot_sector <- "Manufacturing"
# Panel B: vary REGION; fix occupation + sector; pivot region = Eastern Prov.
panelB_occ          <- "Machinery Mechanics and Repairers"
panelB_sector       <- "Manufacturing"
panelB_pivot_region <- "Ash Sharqiyah"
# Panel C: vary OCCUPATION; fix sector + region; pivot occupation = Machinery Mechanics
panelC_sector       <- "Manufacturing"
panelC_region       <- "Ash Sharqiyah"
panelC_pivot_occ    <- "Machinery Mechanics and Repairers"

min_workers       <- 50     # cell employment threshold
unemp_floor       <- 0      # include epsilon-nudged rows in Table B so Riyadh (genuine
                            # minimum-unemployment region) survives the filter

# ---- 2) Working subset + per-cell summariser ----------------------------------------
cells <- emp_data %>%
  filter(year == illus_year, gender == illus_gender,
         !is.na(index.score), !is.na(ISCO3_label),
         !is.na(economicactivity_en), !is.na(name),
         numberofemployees > 0)

summarise_cells <- function(df) {
  df %>%
    group_by(ISCO3_label, economicactivity_en, name) %>%
    summarise(
      Workers      = sum(numberofemployees, na.rm = TRUE),
      sector_score = weighted.mean(sector.score,       numberofemployees, na.rm = TRUE),
      unemp_score  = weighted.mean(unemp.score,        numberofemployees, na.rm = TRUE),
      occ_score    = weighted.mean(occupation.score,   numberofemployees, na.rm = TRUE),
      TRI          = weighted.mean(index.score,        numberofemployees, na.rm = TRUE),
      # raw (pre-normalization) counterparts for display on the x-axis labels
      emissions_raw = weighted.mean(emintens,          numberofemployees, na.rm = TRUE),
      unemp_rate    = weighted.mean(rate,              numberofemployees, na.rm = TRUE),
      .groups = "drop"
    ) %>%
    mutate(inv_occ = 1 - occ_score)
}

# ---- 3) Build three tables anchored on the base case --------------------------------
pick_trio <- function(pool, score_col, base_filter) {
  base_row <- pool %>% filter(!!base_filter)
  if (nrow(base_row) != 1) {
    warning("Base case not found (or not unique) in pool. Check base_* labels and min_workers.")
  }
  # Exclude the base row when picking Low/High so each panel always has three
  # distinct bars — otherwise, when the base case is itself the extreme of the
  # pool, the dedupe step collapses one bar and breaks panel symmetry.
  pool_ex_base <- pool %>% anti_join(
    base_row, by = c("ISCO3_label", "economicactivity_en", "name")
  )
  low  <- pool_ex_base %>% slice_min(.data[[score_col]], n = 1, with_ties = FALSE)
  high <- pool_ex_base %>% slice_max(.data[[score_col]], n = 1, with_ties = FALSE)
  bind_rows(
    low      %>% mutate(case = "Low"),
    base_row %>% mutate(case = "Base"),
    high     %>% mutate(case = "High")
  ) %>% distinct(ISCO3_label, economicactivity_en, name, .keep_all = TRUE)
}

# Panel A: fix occ + region, vary sector
poolA  <- cells %>%
  filter(ISCO3_label == panelA_occ, name == panelA_region) %>%
  summarise_cells() %>% filter(Workers >= min_workers)
tableA <- pick_trio(poolA, "sector_score", quote(economicactivity_en == panelA_pivot_sector))

# Panel B: fix occ + sector, vary region
poolB  <- cells %>%
  filter(ISCO3_label == panelB_occ, economicactivity_en == panelB_sector) %>%
  summarise_cells() %>% filter(Workers >= min_workers, unemp_score >= unemp_floor)
tableB <- pick_trio(poolB, "unemp_score", quote(name == panelB_pivot_region))

# Panel C: fix sector + region, vary occupation (varying metric is inv_occ = 1 - occupation.score)
poolC  <- cells %>%
  filter(economicactivity_en == panelC_sector, name == panelC_region) %>%
  summarise_cells() %>% filter(Workers >= min_workers)
tableC <- pick_trio(poolC, "inv_occ", quote(ISCO3_label == panelC_pivot_occ))

# ---- 4) Apply short labels ----------------------------------------------------------
apply_short <- function(df) {
  df %>% mutate(
    Occupation_short = shorten(ISCO3_label,         occupation_short),
    Sector_short     = shorten(economicactivity_en, sector_short),
    Region_short     = shorten(name,                region_short)
  )
}
tableA <- apply_short(tableA)
tableB <- apply_short(tableB)
tableC <- apply_short(tableC)

# ---- 5) Console prints --------------------------------------------------------------
cat(sprintf("\nIllustration context: gender = %s, year = %s\n", illus_gender, illus_year))
cat(sprintf("  Panel A pivot: %s in %s, %s  (vary sector)\n",
            shorten(panelA_occ, occupation_short),
            shorten(panelA_pivot_sector, sector_short),
            shorten(panelA_region, region_short)))
cat(sprintf("  Panel B pivot: %s in %s, %s  (vary region)\n",
            shorten(panelB_occ, occupation_short),
            shorten(panelB_sector, sector_short),
            shorten(panelB_pivot_region, region_short)))
cat(sprintf("  Panel C pivot: %s in %s, %s  (vary occupation)\n",
            shorten(panelC_pivot_occ, occupation_short),
            shorten(panelC_sector, sector_short),
            shorten(panelC_region, region_short)))

print_table <- function(df, panel_desc) {
  cat(sprintf("\n--- %s ---\n", panel_desc))
  print(df %>%
          select(case, Occupation_short, Sector_short, Region_short,
                 Workers, sector_score, unemp_score, inv_occ, TRI),
        n = Inf)
}
print_table(tableA, "TABLE A: vary SECTOR")
print_table(tableB, "TABLE B: vary REGION")
print_table(tableC, "TABLE C: vary OCCUPATION")

# ---- 6) Save xlsx -------------------------------------------------------------------
illus_wb <- createWorkbook()
addWorksheet(illus_wb, "A_vary_sector")
addWorksheet(illus_wb, "B_vary_region")
addWorksheet(illus_wb, "C_vary_occupation")
writeData(illus_wb, "A_vary_sector",     tableA)
writeData(illus_wb, "B_vary_region",     tableB)
writeData(illus_wb, "C_vary_occupation", tableC)
saveWorkbook(illus_wb, here::here("outputs", "tables", "tri_illustration_tables.xlsx"),
             overwrite = TRUE)


# ==============================================================================
# SECTION 4.4 in manuscript - Sensitivity to weighting assumptions
# REGIONAL TRI WEIGHT SENSITIVITY (2022); also supplies the data for the Figure A1-A3 maps
# Recompute the geometric-mean TRI under three (w_sector, w_unemp, w_occ) combos
# - (0.50, 0.25, 0.25) sector-heavy
# - (0.25, 0.50, 0.25) unemployment-heavy
# - (0.25, 0.25, 0.50) occupation-heavy
# and report employment-weighted regional means (matches the weighted-mean
# convention used for the national avg, regional unemp, and regional green score).
# ==============================================================================

tri_geom <- function(s, u, o, w_s, w_u, w_o) s^w_s * u^w_u * (1 - o)^w_o

weight_sets <- list(
  list(label = "TRI_baseline_equal", w_s = 1/3,  w_u = 1/3,  w_o = 1/3),
  list(label = "TRI_sector_heavy",   w_s = 0.50, w_u = 0.25, w_o = 0.25),
  list(label = "TRI_region_heavy",   w_s = 0.25, w_u = 0.50, w_o = 0.25),
  list(label = "TRI_occ_heavy",      w_s = 0.25, w_u = 0.25, w_o = 0.50)
)

emp_2022 <- emp_data %>% filter(year == 2022)

regional_tri_sens <- emp_2022 %>% distinct(name) %>% arrange(name)
national_tri_sens <- data.frame(
  weight_set       = character(0),
  w_sector         = numeric(0),
  w_unemp          = numeric(0),
  w_occ            = numeric(0),
  national_avg_TRI = numeric(0)
)

for (ws in weight_sets) {
  emp_2022$tri_tmp <- tri_geom(emp_2022$sector.score,
                               emp_2022$unemp.score,
                               emp_2022$occupation.score,
                               ws$w_s, ws$w_u, ws$w_o)

  reg <- emp_2022 %>%
    group_by(name) %>%
    summarise(score = weighted.mean(tri_tmp, numberofemployees, na.rm = TRUE),
              .groups = "drop")
  names(reg)[2] <- ws$label
  regional_tri_sens <- regional_tri_sens %>% left_join(reg, by = "name")

  national_tri_sens <- rbind(national_tri_sens, data.frame(
    weight_set       = ws$label,
    w_sector         = ws$w_s,
    w_unemp          = ws$w_u,
    w_occ            = ws$w_o,
    national_avg_TRI = weighted.mean(emp_2022$tri_tmp,
                                     emp_2022$numberofemployees, na.rm = TRUE)
  ))
}
emp_2022$tri_tmp <- NULL

cat("\n======= REGIONAL TRI WEIGHT SENSITIVITY (2022) =======\n")
cat(sprintf("Baseline (1/3, 1/3, 1/3) national avg TRI 2022: %.4f\n",
            avg_2022))
cat("\nNational avg TRI under each weight set:\n")
print(national_tri_sens, row.names = FALSE)
cat("\nRegional TRI by weight set:\n")
print(regional_tri_sens)

# --- Regional TRI by gender under equal weights (1/3, 1/3, 1/3), 2022 ---------
emp_2022$tri_equal <- tri_geom(emp_2022$sector.score,
                               emp_2022$unemp.score,
                               emp_2022$occupation.score,
                               1/3, 1/3, 1/3)

regional_tri_gender <- emp_2022 %>%
  filter(!is.na(gender)) %>%
  group_by(name, gender) %>%
  summarise(TRI_baseline_equal = weighted.mean(tri_equal, numberofemployees, na.rm = TRUE),
            .groups = "drop") %>%
  pivot_wider(names_from = gender,
              values_from = TRI_baseline_equal,
              names_prefix = "TRI_equal_") %>%
  arrange(name)

emp_2022$tri_equal <- NULL

cat("\nRegional TRI by gender (equal weights):\n")
print(regional_tri_gender)



# ==============================================================================
# FIGURES A1, A2, A3 in manuscript (maps) - the map half of each appendix figure.
# One PNG per non-baseline weighting, mirroring the Figure 4 map exactly.
# ==============================================================================
weight_map_specs <- list(
  list(col = "TRI_sector_heavy", file = "04_tri_map_2022_sector_heavy.png"),  # Figure A1
  list(col = "TRI_region_heavy", file = "05_tri_map_2022_region_heavy.png"),  # Figure A2
  list(col = "TRI_occ_heavy",    file = "06_tri_map_2022_occ_heavy.png")     # Figure A3
)

for (spec in weight_map_specs) {
  df_reg <- regional_tri_sens[, c("name", spec$col)]
  names(df_reg)[2] <- "mean_index"

  df_map <- merge(saudi, df_reg, by = "name")

  lbls <- suppressWarnings(sf::st_point_on_surface(df_map)) %>%
    sf::st_coordinates() %>%
    as.data.frame() %>%
    dplyr::bind_cols(sf::st_drop_geometry(df_map)[, c("name", "mean_index")]) %>%
    dplyr::mutate(
      X = dplyr::case_when(name == "Jizan" ~ 42.75, TRUE ~ X),
      Y = dplyr::case_when(
        name == "Jizan"  ~ 17.30,
        name == "Makkah" ~ Y + 2.5,
        TRUE             ~ Y
      )
    )

  p <- ggplot() +
    geom_sf(data = df_map, aes(fill = mean_index), color = "black") +
    geom_text(data = lbls,
              aes(x = X, y = Y, label = sprintf("%.2f", mean_index)),
              size = 2.0, fontface = "bold", color = "black") +
    scale_fill_viridis_c(option = "E", direction = -1, name = "Average index score",
                         limits = c(0.02, 0.62), alpha = 0.8) +
    theme_void(base_size = 10) +
    theme(legend.position = c(0.85, 0.8),
          legend.text  = element_text(size = 7),
          legend.title = element_text(size = 7, face = "bold"),
          legend.background = element_rect(fill = "white",
                                           linewidth = 0.5, linetype = "solid",
                                           colour = "black"))

  ggsave(here::here("outputs", "figures", spec$file), p, width = 5, height = 5, dpi = 600)
}
cat("Saved: 3 weight-variant TRI maps under outputs/figures/\n")
