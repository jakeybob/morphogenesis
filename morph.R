# https://ipython-books.github.io/124-simulating-a-partial-differential-equation-reaction-diffusion-systems-and-turing-patterns/

library(tidyverse)

#### SETUP ####
pic_dir <- "pics"
data_dir <- "data"
output_video <- "output_a4b5.mp4"
fps <- 60
duration_secs <- 30

# grid params
size <- 120         # size of the 2D grid
dx <- 2 / size      # space step
dt <- 1e-3          # time step
total_time <- duration_secs
n <- as.integer(total_time / dt) + 1 # number of iterations

# initial U,V fields. Write out so can consistently compare effect of different eqn params
# write_rds(matrix(runif(size^2), size), file.path(getwd(), data_dir, paste0("U_", size, ".rds")))
# write_rds(matrix(runif(size^2), size), file.path(getwd(), data_dir, paste0("V_", size, ".rds")))

# eqn params
a <- 4e-4 # joiny-togetherness, 1e-4 more joined and stringy *
b <- 5e-3 # activation strength, 1e-3 weaker
tau <- .1 # timescale, e.g. .2 is slower
k <- -5e-3 # not unlike a, -20e-3 more joined and splodgy

# a = 2,3,4
# b = 3,4,5

label <- paste("list(bolditalic(a) == '4e'^{-4}",  ", bolditalic(b) == '5e'^{-3})")

# ggplot options
opt <- theme(legend.position  = "none",
             panel.background = element_rect(fill="black"),
             plot.margin = margin(-16, 0, -8, -8, unit = "pt"),
             axis.ticks       = element_blank(),
             panel.grid       = element_blank(),
             axis.title       = element_blank(),
             axis.text        = element_blank())

laplacian <- function(Z){
  # returns Laplacian of field
  
  Ztop <- Z[1:(size-2), 2:(size-1)]     # top central (size-2) x (size-2) grid
  Zleft <- Z[2:(size-1), 1:(size-2)]    # left central (size-2) x (size-2) grid
  Zbottom <- Z[3:size, 2:(size-1)]      # bottom central (size-2) x (size-2) grid
  Zright <- Z[2:(size-1), 3:size]       # right central (size-2) x (size-2) grid
  Zcentre <- Z[2:(size-1), 2:(size-1)]  # central (size-2) x (size-2) grid
  
  return( (Ztop + Zleft + Zbottom + Zright -
             (4*Zcentre)) / dx^2 )
}

neumann <- function(Z){
  # sets Neumann boundary conditions, i.e. derivative = 0 on boundary
  
  Z[1, ] <- Z[2, ]            # top row = second row
  Z[size, ] <- Z[(size-1), ]  # bottom row = second bottom row
  Z[, 1] <- Z[, 2]            # first column = second column
  Z[, size] = Z[, (size-1)]   # last column = second last column
  return(Z)
}


#### ITERATE AND SAVE FRAMES ####
for(i in 1:n){
  
  # initialize
  if(i == 1){
    U <- read_rds(file.path(getwd(), data_dir, paste0("U_", size, ".rds")))
    V <- read_rds(file.path(getwd(), data_dir, paste0("V_", size, ".rds")))
  }
  
  # compute the Laplacian of U and V
  deltaU <- laplacian(U)
  deltaV <- laplacian(V)
  
  # take the values of u and v inside central (size-2) x (size-2) grid
  Uc <- U[2:(size-1), 2:(size-1)]
  Vc <- V[2:(size-1), 2:(size-1)]
  
  # update the variables
  U[2:(size-1), 2:(size-1)] <- Uc + dt * (a * deltaU + Uc - Uc^3 - Vc + k)
  V[2:(size-1), 2:(size-1)] <- Vc + dt * (b * deltaV + Uc - Vc) / tau # check operator precedence!!!
  
  # Neumann conditions: derivatives at the edges are null
  U <- neumann(U)
  V <- neumann(V)
  
  # save every ith frame in order to compile required video at specified fps
  if(i %% as.integer(n/(fps*total_time)) == 1){
    filename <- file.path(getwd(), pic_dir, paste0("pic_", str_pad(i, width=str_length(n) + 1, side="left", pad="0"), ".png"))
    
    datU <- as_tibble(U, .name_repair = "unique") %>%
      gather(key = "y", value = "U") %>% 
      mutate(x = rep(1:size, length.out = size^2)) %>%
      mutate(y = sort(rep(1:size, size), method = "auto"))
    
    p <- datU %>%
      ggplot(aes(x = x, y = y)) +
      scale_fill_viridis_c(direction = -1, option = "viridis") + # magma, inferno, plasma, viridis, cividis
      geom_raster(aes(fill = U)) +
      opt +
      annotate("rect", xmin = 20, xmax = 100, ymin = 100, ymax = 124, alpha = .8, fill="black") +
      annotate("text", x = 60, y = 110, label = label, colour="white", parse = T, size = 22)
    
    ggsave(plot = p, filename = filename, width = 12, height = 12, dpi = 30)
    
    print(filename)
  }
}

#### FFMPEG ####
command <- paste0("ffmpeg -y -r ", fps, " -f image2 -s 360x360 -i ", pic_dir, 
                  "/%*.png -vcodec libx264 -crf 20 -pix_fmt yuv420p ", output_video)
system(command = command)
