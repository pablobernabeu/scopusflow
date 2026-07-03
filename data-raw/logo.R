# Generate the scopusflow hex logo (man/figures/logo.png).
#
# Drawn with base grid so it needs no extra packages and stays fully
# reproducible. Two design knobs, deliberately exposed: `name_fontsize` (the
# wordmark size) and `lens_radius` (the magnifier diameter). Run with
#   Rscript data-raw/logo.R
# then regenerate the pkgdown favicons with pkgdown::build_favicons(overwrite =
# TRUE).

library(grid)

# Palette (sampled from the original logo).
navy    <- "#0E2233"  # hexagon fill
teal    <- "#21A6A6"  # hexagon border
glass   <- "#E8F1F2"  # magnifier ring and handle
v_yellow <- "#FDE725" # viridis trend lines, brightest to darkest
v_green  <- "#35B779"
v_blue   <- "#3B528B"

# --- design knobs -----------------------------------------------------------
name_fontsize <- 150   # wordmark size; sits in the hex's full-width band
name_y        <- 0.36  # wordmark centre, lowered further from the top vertex
lens_radius   <- 0.28  # magnifier radius, smaller
# ----------------------------------------------------------------------------

# A regular hexagon with a vertex at top and bottom (flat vertical sides),
# matching the standard R hex-sticker orientation.
hex_angle <- (c(90, 150, 210, 270, 330, 30)) * pi / 180
hx <- cos(hex_angle)
hy <- sin(hex_angle)

# Magnifier geometry.
cx <- 0.02; cy <- -0.25           # lens centre, lowered
handle_angle <- -45 * pi / 180    # lower-right
rim_x <- cx + lens_radius * cos(handle_angle)
rim_y <- cy + lens_radius * sin(handle_angle)
handle_len <- 0.30
tip_x <- cx + (lens_radius + handle_len) * cos(handle_angle)
tip_y <- cy + (lens_radius + handle_len) * sin(handle_angle)

# Three viridis trend lines fanning left-down from a shared peak, longest and
# steepest in blue, mirroring the original.
peak_x <- cx + 0.19; peak_y <- cy + 0.11
ends <- list(
  list(col = v_yellow, x = cx - 0.22, y = cy + 0.05),
  list(col = v_green,  x = cx - 0.23, y = cy - 0.05),
  list(col = v_blue,   x = cx - 0.12, y = cy - 0.20)
)

render <- function() {
  grid.newpage()
  pushViewport(viewport(xscale = c(-1, 1), yscale = c(-1.1, 1.1)))

  # Hexagon, inset slightly so its thick border sits fully inside the canvas.
  grid.polygon(
    hx * 0.965, hy * 0.965, default.units = "native",
    gp = gpar(fill = navy, col = teal, lwd = 20, linejoin = "round")
  )

  # Magnifier handle, drawn first so the rim overlaps its top end.
  grid.lines(
    c(rim_x, tip_x), c(rim_y, tip_y), default.units = "native",
    gp = gpar(col = glass, lwd = 34, lineend = "round")
  )

  # Trend lines and their end points, under the "glass".
  for (e in ends) {
    grid.lines(
      c(peak_x, e$x), c(peak_y, e$y), default.units = "native",
      gp = gpar(col = e$col, lwd = 12, lineend = "round")
    )
    grid.circle(e$x, e$y, r = 0.012, default.units = "native",
                gp = gpar(fill = e$col, col = NA))
  }
  grid.circle(peak_x, peak_y, r = 0.016, default.units = "native",
              gp = gpar(fill = v_green, col = NA))

  # Lens rim on top of the trend and handle.
  grid.circle(cx, cy, r = lens_radius, default.units = "native",
              gp = gpar(col = glass, lwd = 26, fill = NA))

  # Wordmark, prominent in the hexagon's full-width band.
  grid.text(
    "scopusflow", x = unit(0, "native"), y = unit(name_y, "native"),
    gp = gpar(col = "white", fontface = "bold", fontfamily = "sans",
              fontsize = name_fontsize)
  )
  popViewport()
}

png("man/figures/logo.png", width = 1100, height = 1210, bg = "transparent")
render()
dev.off()
message("Wrote man/figures/logo.png")
