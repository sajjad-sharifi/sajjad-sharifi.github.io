# =============================================================================
# ACLED Conflict Hotspot Atlas, Afghanistan
# Spatial diffusion network (district adjacency) + armed-actor network.
# Run on the Mac Mini in a conda-forge R environment (conda activate urban).
# =============================================================================

## ---- 0. Packages -----------------------------------------------------------
pkgs <- c("sf", "spdep", "igraph", "tidygraph", "ggraph", "ggrepel",
          "dplyr", "tidyr", "readr", "stringr", "lubridate",
          "tibble", "ggplot2", "scales")
to_install <- pkgs[!pkgs %in% rownames(installed.packages())]
if (length(to_install)) install.packages(to_install)
invisible(lapply(pkgs, library, character.only = TRUE))

## ---- 1. Config -------------------------------------------------------------
# Edit the two paths. ACLED export (Afghanistan, your range) and admin-2 boundaries.
acled_csv      <- "acled_afghanistan.csv"
districts_path <- "gadm41_AFG_shp/gadm41_AFG_2.shp"
out_dir        <- "outputs"
year_min       <- 2015
year_max       <- 2025
country_name   <- "Afghanistan"

dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
sf::sf_use_s2(FALSE)

rescale01 <- function(x) {
  if (diff(range(x, na.rm = TRUE)) == 0) return(x * 0)
  (x - min(x, na.rm = TRUE)) / diff(range(x, na.rm = TRUE))
}

## ---- 2. Load and clean ACLED ----------------------------------------------
acled <- readr::read_csv(acled_csv, show_col_types = FALSE) %>%
  rename_with(tolower) %>%
  mutate(
    event_date = lubridate::parse_date_time(event_date, orders = c("dmy", "ymd", "mdy")),
    year       = lubridate::year(event_date),
    fatalities = suppressWarnings(as.numeric(fatalities))
  ) %>%
  filter(country == country_name,
         year >= year_min, year <= year_max,
         !is.na(latitude), !is.na(longitude))

message(sprintf("ACLED events loaded: %s (%s to %s)", nrow(acled), year_min, year_max))

## ---- 3. Load district boundaries ------------------------------------------
districts <- sf::st_read(districts_path, quiet = TRUE) %>%
  sf::st_make_valid()

name_candidates <- c("NAME_2", "shapeName", "ADM2_EN", "admin2", "DIST_NAME", "DISTRICT")
prov_candidates <- c("NAME_1", "ADM1_EN", "admin1", "PROV_NAME", "PROVINCE")
dist_field <- intersect(name_candidates, names(districts))[1]
prov_field <- intersect(prov_candidates, names(districts))[1]
if (is.na(dist_field)) stop("No district-name column found. Set dist_field manually.")

districts <- districts %>%
  mutate(node_id   = dplyr::row_number(),
         dist_name = as.character(.data[[dist_field]]),
         prov_name = if (!is.na(prov_field)) as.character(.data[[prov_field]]) else NA_character_)

## ---- 4. Assign events to districts, build conflict intensity ---------------
# Point-in-polygon join, avoids ACLED-to-boundary name mismatches.
events_sf <- sf::st_as_sf(acled, coords = c("longitude", "latitude"), crs = 4326) %>%
  sf::st_transform(sf::st_crs(districts)) %>%
  sf::st_join(districts[, c("node_id", "dist_name", "prov_name")], join = sf::st_within)

intensity <- events_sf %>%
  sf::st_drop_geometry() %>%
  filter(!is.na(node_id)) %>%
  group_by(node_id) %>%
  summarise(events = n(),
            fatalities = sum(fatalities, na.rm = TRUE),
            .groups = "drop")

districts <- districts %>%
  left_join(intensity, by = "node_id") %>%
  mutate(events = tidyr::replace_na(events, 0L),
         fatalities = tidyr::replace_na(fatalities, 0))

## ---- 5. Spatial diffusion network -----------------------------------------
# Queen-contiguity adjacency between districts.
nb  <- spdep::poly2nb(districts, queen = TRUE)
adj <- spdep::nb2mat(nb, style = "B", zero.policy = TRUE)
rownames(adj) <- colnames(adj) <- as.character(districts$node_id)

g_adj <- igraph::graph_from_adjacency_matrix(adj, mode = "undirected", diag = FALSE)
idx <- match(as.integer(V(g_adj)$name), districts$node_id)
V(g_adj)$district <- districts$dist_name[idx]
V(g_adj)$province <- districts$prov_name[idx]

bw  <- igraph::betweenness(g_adj, directed = FALSE, normalized = TRUE)
deg <- igraph::degree(g_adj)
districts$betweenness <- bw[match(as.character(districts$node_id), V(g_adj)$name)]
districts$degree      <- deg[match(as.character(districts$node_id), V(g_adj)$name)]

# Composite score: adjacency betweenness x event count, both rescaled 0-1.
districts <- districts %>%
  mutate(bridge_risk = rescale01(betweenness) * rescale01(events),
         bridge_flag = bridge_risk >= quantile(bridge_risk, 0.90, na.rm = TRUE) & bridge_risk > 0)

## ---- 6. Armed-actor network ------------------------------------------------
# Actor co-event graph from actor1 / actor2. Edge weight = number of shared events.
edges <- acled %>%
  transmute(actor1 = stringr::str_trim(actor1),
            actor2 = stringr::str_trim(actor2)) %>%
  filter(!is.na(actor1), !is.na(actor2),
         actor1 != "", actor2 != "", actor1 != actor2) %>%
  count(actor1, actor2, name = "weight")

g_act <- igraph::graph_from_data_frame(edges, directed = FALSE) %>%
  igraph::simplify(edge.attr.comb = list(weight = "sum"))

comm <- igraph::cluster_louvain(g_act, weights = E(g_act)$weight)

actor_metrics <- tibble::tibble(
  actor       = V(g_act)$name,
  community   = as.integer(igraph::membership(comm)),
  strength    = igraph::strength(g_act, weights = E(g_act)$weight),
  eigen       = igraph::eigen_centrality(g_act, weights = E(g_act)$weight)$vector,
  betweenness = igraph::betweenness(g_act, weights = 1 / E(g_act)$weight, normalized = TRUE)  # invert: weights read as distances
) %>% arrange(desc(eigen))

## ---- 7. Outputs ------------------------------------------------------------
readr::write_csv(
  sf::st_drop_geometry(districts) %>%
    select(node_id, dist_name, prov_name, events, fatalities,
           degree, betweenness, bridge_risk, bridge_flag) %>%
    arrange(desc(bridge_risk)),
  file.path(out_dir, "district_network_metrics.csv"))
readr::write_csv(actor_metrics, file.path(out_dir, "actor_network_metrics.csv"))

p_map <- ggplot(districts) +
  geom_sf(aes(fill = bridge_risk), color = "white", linewidth = 0.1) +
  geom_sf(data = dplyr::filter(districts, bridge_flag),
          fill = NA, color = "#1a5490", linewidth = 0.6) +
  scale_fill_viridis_c(option = "magma", direction = -1, name = "Score") +
  labs(title = "Afghanistan conflict bridge districts",
       subtitle = sprintf("ACLED %s to %s, top decile outlined", year_min, year_max),
       caption = "Adjacency betweenness x event count") +
  theme_void() +
  theme(plot.title = element_text(face = "bold"))
ggsave(file.path(out_dir, "afg_bridge_districts.png"), p_map, width = 10, height = 8, dpi = 200)

top_actors <- actor_metrics %>% slice_max(strength, n = 40) %>% pull(actor)
g_top <- igraph::induced_subgraph(g_act, vids = which(V(g_act)$name %in% top_actors))
V(g_top)$community <- as.factor(as.integer(igraph::membership(comm)[V(g_top)$name]))
V(g_top)$str       <- igraph::strength(g_top, weights = E(g_top)$weight)

p_net <- ggraph(tidygraph::as_tbl_graph(g_top), layout = "fr") +
  geom_edge_link(aes(width = weight), alpha = 0.25, color = "grey50") +
  geom_node_point(aes(color = community, size = str)) +
  geom_node_text(aes(label = name), repel = TRUE, size = 2.6, max.overlaps = 30) +
  scale_edge_width(range = c(0.2, 2.5), guide = "none") +
  scale_size(range = c(2, 9), guide = "none") +
  labs(title = "Armed-actor co-event network, top 40 by activity",
       subtitle = "Color: Louvain community. Size: total events.") +
  theme_void() +
  theme(plot.title = element_text(face = "bold"), legend.position = "none")
ggsave(file.path(out_dir, "afg_actor_network.png"), p_net, width = 11, height = 9, dpi = 200)

## ---- Console summary -------------------------------------------------------
cat("\nTop 10 districts by composite bridge score:\n")
print(sf::st_drop_geometry(districts) %>%
        arrange(desc(bridge_risk)) %>%
        select(dist_name, prov_name, events, betweenness, bridge_risk) %>%
        head(10))

cat("\nTop 10 actors by eigenvector centrality:\n")
print(actor_metrics %>% select(actor, community, strength, eigen) %>% head(10))

cat(sprintf("\nLouvain communities: %s\n", length(unique(igraph::membership(comm)))))
cat(sprintf("Outputs written to: %s\n", normalizePath(out_dir)))

## ---- 8. OPTIONAL: write results to local PostGIS ---------------------------
# Running on the Mac Mini means Postgres is local, so host = localhost.
# library(DBI); library(RPostgres)
# con <- dbConnect(RPostgres::Postgres(),
#                  host = "localhost", port = 5432,
#                  dbname = "urbanrag", user = "YOUR_USER", password = "YOUR_PW")
# sf::st_write(districts, con, layer = "afg_conflict_districts", delete_layer = TRUE)
# DBI::dbWriteTable(con, "afg_actor_metrics", as.data.frame(actor_metrics), overwrite = TRUE)
# dbDisconnect(con)
