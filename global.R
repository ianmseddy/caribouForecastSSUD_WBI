# update this for wherever you have this project stored
repos <- c("https://predictiveecology.r-universe.dev", getOption("repos"))
source("https://raw.githubusercontent.com/PredictiveEcology/pemisc/refs/heads/development/R/getOrUpdatePkg.R")
getOrUpdatePkg(c("Require", "SpaDES.project"), c("1.0.1.9003", "0.1.1.9009")) # only install/update if required
#remotes::install_github("PredictiveEcology/SpaDES.project@development")
# Version should be 0.1.1.9009
#remotes::install_github("PredictiveEcology/reproducible@prepInputsForMacZip2")

projPath <- getwd()

out <- SpaDES.project::setupProject(
  useGit = TRUE,
  name = "caribouForecastSSUD_WBI",
  modules = c("PredictiveEcology/Biomass_borealDataPrep@development",
              "PredictiveEcology/Biomass_core@fixOfOutputs",
              "PredictiveEcology/Biomass_regeneration@development",
              "PredictiveEcology/Biomass_speciesParameters@development",
              "PredictiveEcology/scfm@sfContains",
              #note scfm is a series of modules on a single git repository
              'JWTurn/caribou_SSUD@iansFixes'
              
  ),
  params = list(
    .globals = list(
      dataYear = 2011, #will get kNN 2011 data, and NTEMS 2011 landcover
      sppEquivCol = "LandR",
      .plots = c("png"),
      .studyAreaName=  "caribouWBI_4maps",
      .useCache = c(".inputObjects", "init")
    ),
    Biomass_speciesParamters = list("PSPdataTypes" = "dummy")
  ),
  options = list(#spades.allowInitDuringSimInit = TRUE,
    spades.allowSequentialCaching = TRUE,
    spades.moduleCodeChecks = FALSE,
    spades.recoveryMode = 1, 
    gargle_oauth_client_type = "web", #I think?
    gargle_oauth_email = "ianmseddy@gmail.com",
    gargle_oauth_cache = "../gargleCache"
  ),
  
  packages = c('RCurl', 'XML', 'snow', 'googledrive', 'httr2', "terra"),
  times = list(start = 2011, end = 2031),
  #70 years of fire should be enough to evaluate MAAB ## I'm currently testing
  studyArea = {
    sa <- reproducible::prepInputs(url = 'https://drive.google.com/file/d/1iq1f53pAtZFIFoN1RFhlXEghSbvI3Dnf/view?usp=share_link',
                                   destinationPath = paths$inputPath,
                                   targetFile = "studyArea_bcnwt_4sims.shp",
                                   alsoExtract = "similar", fun = "terra::vect") |>
      reproducible::Cache()
    return(sa)
  },
  studyAreaLarge = {
    terra::buffer(studyArea, 2000)
  },

  rasterToMatchLarge = {
    rtml<- terra::rast(studyAreaLarge, res = c(250,250))
    rtml[] <- 1
    rtml <- terra::mask(rtml, studyAreaLarge)
  },
  rasterToMatch = {
    rtm <- reproducible::postProcess(rasterToMatchLarge, cropTo = studyArea, maskTo = studyArea)
  },
  sppEquiv = {
    speciesInStudy <- LandR::speciesInStudyArea(studyAreaLarge, dPath = "inputs")
    
    species <- LandR::equivalentName(speciesInStudy$speciesList, df = LandR::sppEquivalencies_CA, "LandR")
    sppEquiv <- LandR::sppEquivalencies_CA[LandR %in% species]
    sppEquiv <- sppEquiv[KNN != "" & LANDIS_traits != ""] #avoid a bug with shore pine
  }
)

out$modules <- c("Biomass_borealDataPrep", "Biomass_core",
                 "Biomass_regeneration", "Biomass_speciesParameters",
                 "scfmIgnition", "scfmEscape", "scfmSpread",
                 "scfmDiagnostics", "scfmDataPrep",
                 "caribou_SSUD")
out$paths$modulePath <- c("modules", "modules/scfm/modules")
out$params$scfmDataPrep = list(targetN = 2000,
                               fireRegimePolysType = c("FRU"),
                               # targetN would ideally be minimum 2000 - mean fire size estimates will be bad with 1000
                               .useParallelFireRegimePolys = TRUE) #assumes parallelization is an option

pkgload::load_all("../LandR") #while you wait for NTEMS function
outSim <- SpaDES.core::simInitAndSpades2(out) |>
  reproducible::Cache()
