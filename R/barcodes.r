# Barcode component patterns
.pattern <- list(
  project     = fixed("TCGA"),
  tss         = "^[[:alnum:]]{2}$",
  participant = "^[[:alnum:]]{4}$",
  sample      = "^[[:digit:]]{2}[[:upper:]]?$",
  portion     = "^[[:digit:]]{2}[DGHRTWX]?$",
  drug        = "^[CDHIT][[:digit:]]$",
  exam        = "^E[[:digit:]]+$",
  surgery     = "^S[[:digit:]]+$",
  radiation   = "^R[[:digit:]]+$",
  slide       = "^[TBM]S[[:alnum:]]$",
  center      = "^[0-3][[:digit:]]$",
  plate       = "^[[:alnum:]]{4}$"
)

# Barcode types
.type <- list()
# 2 components
.type$tss <- .pattern[c("project", "tss")]
# 3 components
.type$participant <- c(.type$tss, .pattern["participant"])
# 4 components
.type$drug      <- c(.type$participant, .pattern["drug"])
.type$exam      <- c(.type$participant, .pattern["exam"])
.type$surgery   <- c(.type$participant, .pattern["surgery"])
.type$radiation <- c(.type$participant, .pattern["radiation"])
.type$sample    <- c(.type$participant, .pattern["sample"])
# 5 components (portion/analyte)
.type$portion   <- c(.type$sample,  .pattern["portion"])
# 6 components
.type$slide     <- c(.type$portion, .pattern["slide"]) 
# 7 components 
.type$aliquot   <- c(.type$portion, .pattern["plate"], .pattern["center"])

#' Parse TCGA barcodes
#' 
#' Extract and expand information embedded in TCGA sample barcodes. Details
#' about the barcode format is provided
#' \url{https://wiki.nci.nih.gov/display/TCGA/TCGA+Barcode}{here}.
#' 
#' @export
#' @param x character vector of barcodes
#' @param verbose report barcode type match similarities
#' 
#' @examples
#' barcodes <- c('TCGA-EJ-7321-11A-01R-2263-07', 'TCGA-EJ-7321-11A-01R-2263-07')
#' parse_barcodes(barcodes)   

parse_barcodes <- function(x, annotate = FALSE, verbose = FALSE) {
  
  nparts <- count_barcode_parts(x)
  types <- .type[sapply(.type, length) == nparts]
  
  bparts <- data.frame(str_split_fixed(x, "-", nparts), stringsAsFactors = FALSE)
  
  type.hits <- lapply(types, Map, f = str_detect, string = bparts)
  type.hits <- lapply(type.hits, data.frame)
  type.hits <- lapply(type.hits, apply, 2, mean)
  type.hits <- do.call("rbind", type.hits)
  if (verbose) cat(type.hits)
  type.hits <- rowSums(type.hits)
  
  if (all(type.hits != nparts))
    stop("No matching barcode type was found.", call. = FALSE)
  
  if (sum(type.hits == nparts) > 1)
    stop("Barcodes matched multiple barcode types.", call. = FALSE)
  
  names(bparts) <- names(.type[[names(type.hits)[type.hits == nparts]]])
  
  # extract vial and analyte
  if ("sample" %in% names(bparts)) 
    bparts <- extract_split(bparts, "sample", "vial")
  if ("portion" %in% names(bparts)) 
    bparts <- extract_split(bparts, "portion", "analyte")

  if (!annotate) return(bparts)
  
  .code <- list(
    tss     = "tissueSourceSite",
    sample  = "sampleType",
    analyte = "portionAnalyte",
    center  = "centerCode"
  )
    
  codes <- unlist(.code[names(bparts)])
  names(bparts)[match(names(codes), names(bparts))] <- codes

  for (c in codes) {
    i <- match(c, names(bparts))
    values <- .barcodes[[c]][match(bparts[[c]], .barcodes[[c]]$Code), -1]
    bparts <- data.frame(bparts[-i], values, row.names = NULL, stringsAsFactors = FALSE)
  } 
  
  return(bparts)
}
