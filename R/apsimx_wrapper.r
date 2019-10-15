
#' @title Running .apsimx files from txt input files stored in one directory
#' per `situation`, simulated results are returned in a list
#'
#' @description This function uses ApsimX directly through a system call, can
#' force ApsimX input parameters with values given in arguments.
#'
#' @param param_values named vector containing the value(s) and names of the
#' parameters to force (optional)
#'
#' @param sit_var_dates_mask List of situations, variables and dates for which
#' simulated values should be returned. Typically a list containing the
#' observations to which simulations should be compared as provided by
#' apsimxRFiles::read_obs_to_list
#'
#' @param prior_information Prior information on the parameters to estimate.
#' For the moment only uniform distribution are allowed.
#' Either a list containing (named) vectors of upper and lower
#' bounds (\code{ub} and \code{lb}), or a named list containing for each
#' parameter the list of situations per group (\code{sit_list})
#' and the vector of upper and lower bounds (one value per group) (\code{ub} and \code{lb})
#'
#' @param model_options List containing any information needed by the model.
#' In the case of apsimx: \code{apsimx_path} the path of apsimx executable file and
#' \code{apsimx_file} the path of the directory containing the apsimx input data
#' for each USM (one folder per USM where apsimx input files are stored in txt
#' format)
#'
#' @return A list containing simulated values (\code{sim_list}) and a flag
#' (\code{flag_allsim}) indicating if all required situations, variables and
#' dates were simulated.
#'
#' @examples
#'
#' @export
#'
apsimx_wrapper <- function( param_values=NULL, sit_var_dates_mask=NULL,
                            prior_information=NULL, model_options ) {

  # TODO : make a function dedicated to checking model_options
  # Because it may be model dependant, so it could be possible to pass anything
  # useful in the model running function...
  # Reuse next lines before `Run apsimx` block
  # Check presence of mandatory information in model model_options list

  apsimx_path <- model_options$apsimx_path
  apsimx_file <- model_options$apsimx_file
  warning_display <- model_options$warning_display
  exe <- apsimx_path
  if (.Platform$OS.type == "unix") {
    exe <- paste('mono', exe)
  }

  # Preliminary model checks ---------------------------------------------------
  if (is.null(model_options$apsimx_path) || is.null(model_options$apsimx_file)) {
    stop("apsimx_path and apsimx_file should be elements of the model_model_options
    list for the apsimx model")
  }

  # Test if the model executable file exists is executable ----------------------
  if (!file.exists(apsimx_path)){
    stop(paste("apsimx executable file doesn't exist !",apsimx_path))
  }
  if (!file.exists(apsimx_file)) {
    stop(paste("apsimx file doesn't exist !", apsimx_file))
  }
  val <- try(system(paste(exe,'/Version'),
                    intern = FALSE,
                    ignore.stdout = TRUE),
             silent = TRUE)

  if (val != 0) {
    stop(paste(apsimx_path,"is not executable or is not a apsimx executable !"))
  }

  start_time <- Sys.time()

  # Copy the .apsimx file to a temp file ----------------------------------------
  file_to_run <- tempfile('apsimOnR', fileext = '.apsimx')
  file.copy(apsimx_file, file_to_run)


  # If any parameter value to change
  if ( ! is.null(param_values) ) {
    # Generate config file containing parameter changes ---------------------------
    out <- change_apsimx_param(exe, file_to_run, param_values)

    if (!out) {
      stop(paste("Error when changing parameters in", file_to_run))
    }

    # config_file <- tempfile('apsimOnR', fileext = '.conf')
    # parameter_names <- names(param_values)
    # fileConn <- file(config_file)
    # lines <- vector("character", length(param_values))
    # for (i in 1:length(param_values))
    #   lines[i] <- paste(parameter_names[i], '=', as.character(param_values[i]))
    # writeLines(lines, fileConn)
    # close(fileConn)
    #
    # # Apply parameter changes to the model -----------------------------------------
    # cmd <- paste(exe, file_to_run, '/Edit', config_file)
    # #edit_file_stdout <- shell(cmd, translate = FALSE, intern = TRUE, mustWork = TRUE)
    # edit_file_stdout <- system(cmd, intern = TRUE)

    #print(stdout)
  }


  # Run apsimx ------------------------------------------------------------------
  cmd <- paste(exe, file_to_run)
  if (model_options$multi_process)
    cmd <- paste(cmd, '/MultiProcess')

  # run_file_stdout <- shell(cmd, translate = FALSE, intern = TRUE)
  # Portable version for system call
  run_file_stdout <- system(cmd,
                            ignore.stdout = TRUE,
                            ignore.stderr = TRUE)

  # Getting the execution status
  flag_allsim <- !run_file_stdout

  # Store results ---------------------------------------------------------------
  db_file_name <- gsub('.apsimx', '.db', file_to_run)

  predicted_data <- read_apsimx_output(db_file_name,
                                       model_options$predicted_table_name,
                                       model_options$variable_names)
  #observed_data <- read_apsimx_output(db_file_name, model_options$observed_table_name, model_options$variable_names)

  # Display simulation duration -------------------------------------------------
  if (model_options$time_display) {
    duration <- Sys.time() - start_time
    print(duration)
  }

  return(list(sim_list = predicted_data, flag_allsim = flag_allsim))

}



apsimx_display_warnings <- function(in_string) {
  # print(in_string)
  # print(length(in_string))
  if (nchar(in_string) ) warning(in_string, call. = FALSE)
}
