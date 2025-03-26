# update this for wherever you have this project stored
repos <- c("https://predictiveecology.r-universe.dev", getOption("repos"))
source("https://raw.githubusercontent.com/PredictiveEcology/pemisc/refs/heads/development/R/getOrUpdatePkg.R")
getOrUpdatePkg(c("Require", "SpaDES.project"), c("1.0.1.9003", "0.1.1.9009")) # only install/update if required
#remotes::install_github("PredictiveEcology/SpaDES.project@development")
# Version should be 0.1.1.9009
#remotes::install_github("PredictiveEcology/reproducible@prepInputsForMacZip2")



# update this for wherever you have this project stored
projPath = "caribouForecastSSUD_WBI"


out <- SpaDES.project::setupProject(
  Restart = TRUE,
  useGit = TRUE,
  updateRprofile = FALSE,
  paths = list(projectPath = "caribouForecastSSUD_WBI"),
  
  modules = c("PredictiveEcology/Biomass_borealDataPrep@development",
              "PredictiveEcology/Biomass_core@main",
              "PredictiveEcology/Biomass_regeneration@development",
              "PredictiveEcology/Biomass_speciesParameters@development",
              "PredictiveEcology/scfm@development",
              #note scfm is a series of modules on a single git repository
              'JWTurn/caribou_SSUD@master'
              
  ),
  params = list(
    .globals = list(
      dataYear = 2011, #will get kNN 2011 data, and NTEMS 2011 landcover
      sppEquivCol = "LandR",
      .plots = c("png"),
      .studyAreaName=  "caribouWBI_4maps",
      .useCache = c(".inputObjects", "init")
    ),
    Biomass_speciesParamters = list("PSPdataTypes" = "dummy"),
    scfmDataPrep = list(targetN = 2000,
                        fireRegimePolysType = c("FRU"),
                        # targetN would ideally be minimum 2000 - mean fire size estimates will be bad with 1000
                        .useParallelFireRegimePolys = TRUE) #assumes parallelization is an option
  ),
  options = list(#spades.allowInitDuringSimInit = TRUE,
    spades.allowSequentialCaching = TRUE,
    spades.moduleCodeChecks = FALSE,
    spades.recoveryMode = 1
  ),
  
  packages = c('RCurl', 'XML', 'snow', 'googledrive', 'httr2', "terra"),
  times = list(start = 2011, end = 2031),
  #70 years of fire should be enough to evaluate MAAB ## I'm currently testing
  studyArea = {
    sa <- reproducible::prepInputs(url = 'https://drive.google.com/file/d/1XduunieEoZLcNPQphGXnKG7Ql9MF1bme/view?usp=share_link',
                                   destinaionPath = file.path(projPath, "data", "prepInputs"),
                                   targetFile = "studyArea_4maps.shp",
                                   alsoExtract = "similar", fun = "terra::vect")
  },
  # my area is so large probably don't need saLarge and rastertomatchLarge ****
  studyAreaLarge = {
    terra::buffer(studyArea, 2000)
  },
  # my area is so large probably don't need saLarge and rastertomatchLarge ****
  studyAreaLarge = sf::st_buffer(studyArea, 10000),
  
  rasterToMatchLarge = {
    rtml<- terra::rast(studyAreaLarge, res = c(250,250))
    rtml[] <- 1
    rtml <- terra::mask(rtml, studyAreaLarge)
  },
  rasterToMatch = {
    rtm <- reproducible::postProcess(rasterToMatchLarge, cropTo = studyArea, maskTo = studyArea)
  },
  sppEquiv = {
    speciesInStudy <- LandR::speciesInStudyArea(studyAreaLarge)
    speciesInStudy <- LandR::speciesInStudyArea(studyAreaLarge, dPath = "inputs")
    
    species <- LandR::equivalentName(speciesInStudy$speciesList, df = LandR::sppEquivalencies_CA, "LandR")
    sppEquiv <- LandR::sppEquivalencies_CA[LandR %in% species]
    sppEquiv <- sppEquiv[KNN != "" & LANDIS_traits != ""] #avoid a bug with shore pine
  }
)

outSim <- SpaDES.core::simInitAndSpades2(out) |>
  reproducible::Cache()
