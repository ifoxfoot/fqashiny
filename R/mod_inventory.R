#' inventory UI Function
#'
#' @description A shiny Module.
#'
#' @param id,input,output,session Internal parameters for {shiny}.
#'
#' @noRd
#'
#' @importFrom shiny NS tagList
mod_inventory_ui <- function(id){
  ns <- NS(id)
  tagList(
    shinyglide::glide(
      id = ns("glide"),
      next_label = paste("Calculate FQA Metrics ", icon("arrow-right")),
      previous_label = paste(icon("arrow-left"), "Go Back to Data Entry"),
      controls_position = "bottom",
      height = "100%",
      keyboard = FALSE,

      shinyglide::screen(
        next_condition = "output['inventory-next_condition'] == 'TRUE'",

        fluidRow(
          sidebarPanel(

            titlePanel("Enter Data"),

            #help button
            shinyWidgets::circleButton(ns("help"), icon = icon("question"),
                         style = "position:absolute; top:5px; right:5px;",
                         status = "primary"),

            #input regional data base
            selectInput(ns("db"), label = "Select Regional FQA Database",
                        choices = fqacalc::db_names()$fqa_db,
                        selected = "michigan_2014"),

            #when db has incomplete acronyms hide acronym option
            conditionalPanel(

              condition = "output['inventory-complete_acronym'] == 'TRUE'",
              #input key argument
              shinyWidgets::radioGroupButtons(ns("key"), label = "Enter Species Using: ",
                                choices = c("Scientific Names" = "name",
                                            "Acronyms" = "acronym"),
                                selected = "name",
                                justified = TRUE,
                                checkIcon = list(yes = icon("ok",
                                                            lib = "glyphicon"))),
            ),

            #input data entry method
            shinyWidgets::prettyRadioButtons(ns("input_method"), label = "Select Data Entry Method",
                               choices = c( "Enter Species Manually" = "enter",
                                            "Upload a File" = "upload")),



            #when data entry method is upload, allow user to upload files
            conditionalPanel(

              condition = "input['inventory-input_method'] == 'upload'",

              #input file upload widget
              fileInput(ns("upload"), NULL, buttonLabel = "Upload...", multiple = F),

              #input what column to use to bind to FQA database
              uiOutput(ns("species_colname")),

              #input button to delete uploaded file
              actionButton(ns("upload_delete_all"), "Delete Uploaded File")

            ), #conditional 1 parenthesis

            #when data entry method is enter, allow user to enter data manually
            conditionalPanel(

              condition = "input['inventory-input_method'] == 'enter'",

              #input latin name
              selectizeInput(ns("select_species"), label = "Select Species",
                             choices = NULL, selected = NULL, multiple = TRUE),

              fluidRow(
                #input add species button
                actionButton(ns("add_species"), "Add Species",
                             style = "margin-left: 15px;"),
                #input delete speces button
                actionButton(ns("delete_species"), "Delete Species",
                             style = "margin-left: 10px;")),

              br(),

              #button to delete all entries
              actionButton(ns("manual_delete_all"), "Delete All Entries", class = "btn-danger")

            ) #conditional 2 parenthesis

          ), #side bar panel

          mainPanel(

            textOutput(ns("next_condition")),
            textOutput(ns("complete_acronym")),

            #when user wants to upload a file but hasn't yet, show instructions
            conditionalPanel("input['inventory-input_method'] == 'upload' && output['inventory-file_is_uploaded'] != true",
                             br(),
                             h3("File uploads must have one column containing either scientific names
                              or acronyms. The columns must go to the top of the file such that row 1
                              is the column name.")),

            #when user uploads file, show uploaded table
            conditionalPanel("input['inventory-input_method'] == 'upload'",
                             br(),
                             br(),
                             DT::dataTableOutput(NS(id, "upload_table"))),

            #when user enters species manually, show what they enter
            conditionalPanel("input['inventory-input_method'] == 'enter'",
                             br(),
                             br(),
                             DT::dataTableOutput(NS(id, "manual_table")))

          )#main panel parenthesis

        )#fluidRow parenthesis

      ),#screen 1 parenthesis

      shinyglide::screen(

        #download button
        downloadButton(ns("download"),
                       label = "Download", class = "downloadButton",
                       style = "position: absolute; top: 0px; right: 0px;"),
        br(),
        #title
        column(12, align = "center",
               h3(textOutput(ns("title")))),


        #boxes with key values
        fluidRow(
          shinydashboard::valueBox(
            htmlOutput(ns("species_richness")),
            "Species Richness", color = "navy"
          ),
          shinydashboard::valueBox(
            htmlOutput(ns("mean_c")),
            "Mean C",
            icon = icon("seedling"), color = "olive"
          ),
          shinydashboard::valueBox(
            htmlOutput(ns("fqi")),
            "Total FQI",
            icon = icon("pagelines"), color = "green"
          )
        ),#fluidRow parenthesis

        #all mets and graph
        fluidRow(
          shinydashboard::box(plotOutput(ns("binned_c_score_plot")),
              title = "Binned Histogram of C Values"),
          shinydashboard::box(plotOutput(ns("c_hist")),
              title = "Histogram of C Values")
        ),

        fluidRow(
          column(4,
                 shinydashboard::box(tableOutput(ns("c_metrics")), title = "FQI Metrics", width = NULL),
                 shinydashboard::box(tableOutput(NS(id,"duration_table")), title = "Duration Metrics", width = NULL,
                     style = "overflow-x: scroll")),
          column(4,
                 shinydashboard::box(tableOutput(ns("wetness")), title = "Wetness Metrics", width = NULL),
                 shinydashboard::box(tableOutput(ns("pysiog_table")), title = "Physiognomy Metrics", width = NULL,
                     style = "overflow-x: scroll")),
          column(4,
                 shinydashboard::box(tableOutput(ns("species_mets")), title = "Species Richness Metrics", width = NULL),
                 shinydashboard::box(tableOutput(ns("proportion")), title = "C Value Percentages", width = NULL))
        ),

        #output of accepted entries
        fluidRow(shinydashboard::box(title = "Data Entered", status = "primary",
                                     DT::dataTableOutput(ns( "accepted")), width = 12,
                                     style = "overflow-x: auto;l"))


      )#screen 2 parenthesis

    )#glide parenthesis

  )
}

#' inventory Server Functions
#'
#' @noRd
mod_inventory_server <- function(id){
  moduleServer( id, function(input, output, session){

    ns <- session$ns

    #creating a reactive value for glide page, used as input to server fun
    fqi_glide <- reactive({input$shinyglide_index_glide})

    #reactive key
    key <- reactiveVal()

    #update key
    observe({
      if(any(is.na(fqacalc::view_db(input$db)$acronym) &
             fqacalc::view_db(input$db)$name_origin == "accepted_scientific_name"))
        key("name")
      else(key(input$key))
    })

    #making input method reactive
    input_method <- reactive({input$input_method})

    #initialize reactives to hold data entered/uploaded
    file_upload <- reactiveVal()
    data_entered <- reactiveVal({data.frame()})

    #help popup
    observeEvent(input$help, {
      inventory_help()
    })

    #create reactive for complete acronym test
    complete_acronym <- reactiveVal({})

    #test if db contains complete acronyms (T/F), store in reactive
    observeEvent(input$db, {
      regional_fqai <- fqacalc::view_db(input$db)
      acronym <- if( any(is.na(regional_fqai$acronym)
                         & regional_fqai$name_origin == "accepted_scientific_name") )
      {FALSE} else {TRUE}
      complete_acronym(acronym)
    })

    #create complete acronym output
    output$complete_acronym <- renderText(
      complete_acronym()
    )

    #hide complete_acronym output
    observe({shinyjs::hide("complete_acronym",)})
    outputOptions(output, "complete_acronym", suspendWhenHidden=FALSE)

    #file upload server-------------------------------------------------------------

    #if file is uploaded, show T, else F
    output$file_is_uploaded <- reactive({
      return(!is.null(file_upload()))
    })
    outputOptions(output, "file_is_uploaded", suspendWhenHidden = FALSE)

    #When file is uploaded, upload and store in reactive object above
    observeEvent(input$upload, {
      #require that a file be uploaded
      req(input$upload)
      #getting extension
      ext <- tools::file_ext(input$upload$name)
      #reading in differently based on extension
      new_file <- switch(ext,
                         csv = vroom::vroom(input$upload$datapath, delim = ","),
                         tsv = vroom::vroom(input$upload$datapath, delim = "\t"),
                         xlsx = readxl::read_excel(input$upload$datapath),
                         validate("Invalid file; Please upload a .csv, .tsv, or .xlsx file")) %>%
        #drop empty data
        dplyr::filter(., rowSums(is.na(.)) != ncol(.)) %>%
        as.data.frame(.)
      #store upload in reactive object
      file_upload(new_file)
    })


    #drop-down list (for species column) based on the file uploaded
    observeEvent(input$upload,{
      output$species_colname <- renderUI({
        #create list cols
        colnames <- c("", colnames(file_upload()))
        #create var for key
        key_var <- if(key() == "name") {"Scientific Names"} else {"Acronyms"}
        #create a dropdown option
        selectizeInput(ns("species_column"),
                       paste0("Which Column Contains ", key_var, "?"),
                       colnames, selected = NULL)
      })
    })

    #warnings for bad data in file upload
    observeEvent(input$species_column, {
      req(nrow(file_upload()) >= 1)
      req(input$species_column != "")

      #list to store warnings
      warning_list <- list()
      #catch warnings
      withCallingHandlers(
        accepted_file <- fqacalc::accepted_entries(file_upload() %>%
                                            dplyr::rename(!!as.name(key()) := input$species_column),
                                          key = key(),
                                          db = input$db,
                                          native = FALSE),
        #add to list
        message=function(w) {warning_list <<- c(warning_list, list(w$message))})
      #show each list item in notification
      for(i in warning_list) {
        shinyalert::shinyalert(text = strong(i), type = "warning", html = T) }
    })

    #render output table from uploaded file
    output$upload_table <- DT::renderDT({
      DT::datatable(file_upload(),
                selection = 'single',
                options = list(autoWidth = TRUE,
                               scrollX = TRUE,
                               searching = FALSE,
                               lengthChange = FALSE)
      )
    })

    #when delete all is clicked, clear all entries
    observeEvent(input$upload_delete_all, {
      #make an empty df
      empty_df <- NULL
      #replace reactive file upload with empty file
      file_upload(empty_df)
      accepted(empty_df)
      #reset upload button
      shinyjs::reset("upload")
      shinyjs::reset("species_column")
    })

    #manually enter data------------------------------------------------------------

    #species drop-down list based on regional database selected
    observe({
      req(input$db)
      #create list names based on regional database selected
      names <- if(key() == "name")
      {c("", unique(fqacalc::view_db(input$db)$name))}
      else {c("", unique(fqacalc::view_db(input$db)$acronym))}
      #create a dropdown option
      updateSelectizeInput(session, "select_species",
                           choices =  names,
                           selected = character(0),
                           server = TRUE)
    })

    #When add species is clicked, add row
    observeEvent(input$add_species, {
      #list species
      new_entry <-  c(input$select_species)
      #bind new entry to table
      new_row <- fqadata::fqa_db %>%
        dplyr::filter(fqa_db == input$db) %>%
        dplyr::filter(!!as.name(key()) %in% c(new_entry))
      #update reactive to new table
      if (nrow(data_entered() > 0)) {
        data_entered( rbind(new_row, accepted()) )
      } else data_entered(new_row)
      #reset drop down menu of latin names
      shinyjs::reset("select_species")
    })

    #this allows popups for warnings about duplicates/non-matching species
    observeEvent(input$add_species,{
      nrow(data_entered()) > 0
      #list to store warnings
      warning_list <- list()
      #catch warnings
      withCallingHandlers(
        fqacalc::accepted_entries(x = data_entered(),
                                  key = key(),
                                  db = input$db,
                                  native = FALSE,
                                  wetland_warning = FALSE),
        #add to list
        message=function(w) {warning_list <<- c(warning_list, list(w$message))})
      #show each list item in notification
      for(i in warning_list) {
        shinyalert::shinyalert(text = strong(i), type = "warning", html = T) }
    })

    #render output table from manually entered species on data entry page
    output$manual_table <- DT::renderDT({
      DT::datatable(accepted(),
                selection = 'single',
                options = list(autoWidth = TRUE,
                               scrollX = TRUE,
                               searching = FALSE,
                               lengthChange = FALSE)
      )
    })

    #when delete species is clicked, delete row
    observeEvent(input$delete_species,{
      #call table
      t = accepted()
      #print table
      print(nrow(t))
      #if rows are selected, delete them
      if (!is.null(input$manual_table_rows_selected)) {
        t <- t[-as.numeric(input$manual_table_rows_selected),]
      }
      #else show the regular table
      accepted(t)
    })

    #when delete all is clicked, clear all entries
    observeEvent(input$manual_delete_all, {
      empty_df <- data.frame()
      data_entered(empty_df)
      accepted(empty_df)
    })

    #creating accepted df ----------------------------------------------------------

    #initialize reactives
    accepted <- reactiveVal(data.frame())
    confirm_db <- reactiveVal("empty")
    previous_dbs <- reactiveValues(prev = "michigan_2014")

    #store current and previous db value in reactive element
    observeEvent(input$db, {
      previous_dbs$prev <- c(tail(previous_dbs$prev, 1), input$db)
    })

    #if input method is enter, accepted is from data_entered
    observe({
      req(input_method() == "enter", nrow(data_entered()) > 0)
      accepted(suppressMessages(fqacalc::accepted_entries(x = data_entered(),
                                                          key = key(),
                                                          db = input$db,
                                                          native = FALSE,
                                                          allow_duplicates = FALSE,
                                                          allow_non_veg = FALSE,
                                                          allow_no_c = TRUE)))
    })

    #if input method is upload, accepted is from file upload
    observe({
      req(input_method() == "upload")
      accepted(data.frame())

      req(input_method() == "upload", nrow(file_upload()) > 0, input$species_column)
      accepted(suppressMessages(fqacalc::accepted_entries(x = file_upload() %>%
                                                            dplyr::rename(!!as.name(key()) := input$species_column),
                                                          key = key(),
                                                          db = input$db,
                                                          native = FALSE,
                                                          allow_duplicates = FALSE,
                                                          allow_non_veg = FALSE,
                                                          allow_no_c = TRUE)))
    })

    #if db is changed and there is already data entered, show popup
    observeEvent(input$db, {
      req(nrow(data_entered()) > 0 || nrow(file_upload()) > 0)
      #code for popup
      if(confirm_db() != "empty") {
        confirm_db("empty") }
      else{
        shinyalert::shinyalert(text = strong(
          "Changing the regional database will delete your current data entries.
        Are you sure you want to proceed?"),
          showCancelButton = T,
          showConfirmButton = T, confirmButtonText = "Proceed",
          confirmButtonCol = "red", type = "warning",
          html = T, inputId = "confirm_db_change")}
    })

    observeEvent(input$confirm_db_change, {
      #store confirmation in reactive value
      confirm_db(input$confirm_db_change)
      #create an empty df
      empty_df <- data.frame()
      #if confirm db is true and method is enter, reset entered data
      if(confirm_db() == TRUE) {
        data_entered(empty_df)
        file_upload(NULL)
        accepted(empty_df)
        shinyjs::reset("upload")
        shinyjs::reset("species_column")
        shinyWidgets::updateRadioGroupButtons(session, inputId = "key",
                                label = "Enter Species Using: ",
                                choices = c("Scientific Names" = "name",
                                            "Acronyms" = "acronym"),
                                justified = TRUE,
                                checkIcon = list(yes = icon("ok",
                                                            lib = "glyphicon")))
        confirm_db("empty")}
      #if confirm db is false, reset db to previous value
      if (confirm_db() == FALSE) {
        updateSelectInput(session, inputId = "db",
                          label = "Select Regional FQA Database",
                          choices = fqacalc::db_names()$fqa_db,
                          selected = previous_dbs$prev[1])
      }
    })

    #wetland warnings
    observeEvent(input$db, {
      if( all(is.na(fqacalc::view_db(input$db)$w)) ) {
        shinyalert::shinyalert(text = strong(paste(input$db, "does not have wetland coefficients,
                                       wetland metrics cannot be calculated.")), type = "warning", html = T)
      }
      if( input$db == "wyoming_2017") {
        shinyalert::shinyalert(text = strong("The Wyoming FQA database is associated with multiple
                                 wetland indicator status regions. This package defaults
                                 to the Arid West wetland indicator region when
                                 calculating Wyoming metrics."), type = "warning", html = T)
      }
      if ( input$db == "colorado_2020" ){
        shinyalert::shinyalert(text = strong("The Colorado FQA database is associated with
                                 multiple wetland indicator status regions. This
                                 package defaults to the Western Mountains,
                                 Valleys, and Coasts indicator region when calculating
                                 Colorado metrics."), type = "warning", html = T)
      }
    })

    #create boolean that shows if data is entered or not for next condition
    output$next_condition <- renderText(
      nrow(accepted()) > 0
    )

    #hide next condition output
    observe({shinyjs::hide("next_condition",)})
    outputOptions(output, "next_condition", suspendWhenHidden=FALSE)

    #second screen -----------------------------------------------------------------

    #initializing reactives for outputs
    metrics <- reactiveVal()
    physiog_table <- reactiveVal()
    duration_table <- reactiveVal()

    #download cover summary server
    output$download <- downloadHandler(
      #name of file based off of transect
      filename = function() {
        paste0("FQA_assessment_", Sys.Date(), ".zip")
      },
      #content of file
      content = function(file) {
        #set wd to temp directory
        tmpdir <- tempdir()
        setwd(tempdir())

        # Start a sink file with a CSV extension
        sink("FQI_metrics.csv")
        cat('\n')
        cat(paste0("Calculating metrics based on the ", input$db, " regional FQAI."))
        cat('\n')
        cat('\n')

        # Write metrics dataframe to the same sink
        write.csv(metrics() %>%
                    dplyr::mutate(values = round(values, digits = 2)), row.names = F)
        cat('\n')
        cat('\n')

        cat("Physiognomy Metrics")
        cat('\n')
        write.csv(physiog_table() %>%
                    dplyr::mutate(percent = round(percent, digits = 2)), row.names = F)
        cat('\n')
        cat('\n')

        cat("Duration Metrics")
        cat('\n')
        write.csv(duration_table() %>%
                    dplyr::mutate(percent = round(percent, digits = 2)), row.names = F)
        cat('\n')
        cat('\n')

        cat('Species Entered')
        cat('\n')
        write.csv(accepted(), row.names = F)

        # Close the sink
        sink()

        #now add two ggplots as pngs
        ggplot2::ggsave( "binned_hist.png", plot = binned_c_score_plot(metrics()),
                device = "png", bg = 'white')
        ggplot2::ggsave( "c_value_hist.png", plot = c_score_plot(accepted()), bg='#ffffff',
                device = "png")

        # Zip them up
        zip( file, c("FQI_metrics.csv", "binned_hist.png", "c_value_hist.png"))
      })

    #get all metrics
    observe({
      req(fqi_glide() == 1)
      metrics(suppressMessages(fqacalc::all_metrics(x = accepted(), db = input$db, allow_no_c = TRUE)))
    })

    #get pysiog and duration table
    observe({
      req(nrow(accepted()) > 0 & fqi_glide() == 1)

      #write df with all cats to include
      physiog_cats <- data.frame(physiognomy = c("tree", "shrub", "vine", "forb", "grass",
                                                 "sedge", "rush", "fern", "bryophyte"),
                                 number = rep.int(0, 9),
                                 percent = rep.int(0,9))

      duration_cats <- data.frame(duration = c("annual", "perennial", "biennial"),
                                  number = rep.int(0, 3),
                                  percent = rep.int(0,3))

      #count observations in accepted data
      phys <- accepted() %>%
        dplyr::group_by(physiognomy) %>%
        dplyr::summarise(number = dplyr::n()) %>%
        dplyr::mutate(percent = round((number/sum(number))*100, 2)) %>%
        rbind(physiog_cats %>% dplyr::filter(!physiognomy %in% accepted()$physiognomy)) %>%
        dplyr::mutate(number = as.integer(number))

      dur <- accepted() %>%
        dplyr::group_by(duration) %>%
        dplyr::summarise(number = dplyr::n()) %>%
        dplyr::mutate(percent = round((number/sum(number))*100, 2)) %>%
        rbind(duration_cats %>% dplyr::filter(!duration %in% accepted()$duration)) %>%
        dplyr::mutate(number = as.integer(number))

      #store in reactive
      physiog_table(phys)
      duration_table(dur)
    })

    #render title
    output$title <-
      renderText({paste("Calculating metrics based on ", input$db)})

    #species richness
    output$species_richness <- renderUI({
      req(fqi_glide() == 1)
      round(
        suppressMessages(fqacalc::species_richness(x = accepted(), db = input$db, native = F, allow_no_c = TRUE)),
        2)
    })

    #mean C
    output$mean_c <- renderUI({
      req(fqi_glide() == 1)
      round(suppressMessages(fqacalc::mean_c(x = accepted(), db = input$db, native = F)), 2)
    })

    #total fqi
    output$fqi <- renderUI({
      req(fqi_glide() == 1)
      round(suppressMessages(fqacalc::FQI(x = accepted(), db = input$db, native = F)), 2)
    })

    #metrics table output
    output$c_metrics <- renderTable({
      req(fqi_glide() == 1)
      metrics() %>%
        dplyr::filter(metrics %in% c("Mean C", "Native Mean C", "Total FQI",
                                     "Native FQI", "Adjusted FQI"))
    })

    #wetness table output
    output$wetness <- renderTable({
      req(fqi_glide() == 1)
      metrics() %>%
        dplyr::filter(metrics %in% c("Mean Wetness",
                                     "Native Mean Wetness",
                                     "% Hydrophytes"))
    })

    #nativity table output
    output$species_mets <- renderTable({
      req(fqi_glide() == 1)
      metrics() %>%
        dplyr::filter(metrics %in% c("Total Species Richness",
                                     "Native Species Richness",
                                     "Exotic Species Richness")) %>%
        dplyr::mutate(values = as.integer(values))
    })

    #proportion table output
    output$proportion <- renderTable({
      req(fqi_glide() == 1)
      metrics() %>%
        dplyr::filter(metrics %in% c("% of Species with no C Value",
                                     "% of Species with 0 C Value",
                                     "% of Species with 1-3 C Value",
                                     "% of Species with 4-6 C Value",
                                     "% of Species with 7-10 C Value"))
    })

    #ggplot output
    output$c_hist <- renderPlot({
      req(fqi_glide() == 1)
      c_score_plot(accepted())
    })

    #ggplot output
    output$binned_c_score_plot <- renderPlot({
      req(fqi_glide() == 1)
      binned_c_score_plot(metrics())
    })

    #physiog table output
    output$pysiog_table <- renderTable({
      req(fqi_glide() == 1)
      physiog_table()
    })

    #duration table output
    output$duration_table <- renderTable({
      req(fqi_glide() == 1)
      duration_table()
    })

    #accepted summary
    output$accepted <- DT::renderDataTable({
      #requiring second screen
      req(fqi_glide() == 1)
      #call to reactive species summary
      DT::datatable(accepted(),
                    #options
                    options = list(scrollX=TRUE,
                                   scrollY= TRUE,
                                   paging = TRUE,
                                   pageLength = 20,
                                   searching = TRUE,
                                   fixedColumns = TRUE,
                                   autoWidth = TRUE,
                                   ordering = TRUE))
    })


  })
}

## To be copied in the UI
# mod_inventory_ui("inventory_1")

## To be copied in the server
# mod_inventory_server("inventory_1")
