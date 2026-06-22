# A local-first Shiny app over scopusflow. It runs on the user's own machine, so
# the API key never leaves it and the requests originate from the user's own
# (institutional) network, which is what the Scopus API expects. The long
# retrieval runs in a background callr process whose verbose cli output is tailed
# into a live terminal panel, and a reproducible script mirrors every choice.

# The worker run in a fresh background R session by callr::r_bg(). It must be
# self-contained: it references scopusflow with `::` so the child loads the
# installed package, forces cli colour, and runs the harvest verbosely so the
# parent can tail its progress.
app_fetch_worker <- function(query, years, field, view, partition,
                             max_results, cache_dir, api_key) {
  options(cli.num_colors = 256L, cli.default_num_colors = 256L, crayon.enabled = TRUE)
  plan <- scopusflow::scopus_plan(
    query, years = years, field = field, view = view, partition = partition
  )
  scopusflow::scopus_fetch_plan(
    plan, max_results = max_results, cache_dir = cache_dir,
    resume = TRUE, api_key = api_key, verbose = TRUE
  )
}

# Common Scopus field tags offered in the UI (a "(none)" option leaves the query
# untagged).
app_field_choices <- function() {
  c(
    "Title, abstract, keywords" = "TITLE-ABS-KEY",
    "Title" = "TITLE",
    "Abstract" = "ABS",
    "Keywords" = "AUTHKEY",
    "Author" = "AUTHLASTNAME",
    "Affiliation" = "AFFIL",
    "Source title" = "SRCTITLE",
    "All fields" = "ALL",
    "(none)" = ""
  )
}

app_ui <- function() {
  this_year <- as.integer(format(Sys.Date(), "%Y"))
  bslib::page_sidebar(
    title = "scopusflow",
    theme = bslib::bs_theme(version = 5, primary = "#21A6A6"),
    sidebar = bslib::sidebar(
      width = 340,
      shiny::passwordInput("api_key", "Scopus API key",
                           placeholder = "paste your key (stays on this machine)"),
      shiny::uiOutput("key_status"),
      shiny::hr(),
      shiny::textInput("query", "Search terms", value = "graphene supercapacitor"),
      shiny::selectInput("field", "Search in", choices = app_field_choices(),
                         selected = "TITLE-ABS-KEY"),
      shiny::checkboxInput("use_years", "Partition by year (recommended)", value = TRUE),
      shiny::conditionalPanel(
        "input.use_years == true",
        shiny::sliderInput("years", "Years", min = 1960L, max = this_year,
                           value = c(this_year - 5L, this_year), sep = "")
      ),
      shiny::radioButtons("view", "Detail", inline = TRUE,
                          choices = c("STANDARD", "COMPLETE")),
      shiny::numericInput("max_results", "Max records per year (blank = all)",
                          value = 200L, min = 1L),
      shiny::hr(),
      shiny::actionButton("count", "Check size", class = "btn-outline-primary w-100 mb-2"),
      shiny::actionButton("fetch", "Fetch records",
                          class = "btn-primary w-100 mb-2", icon = shiny::icon("download")),
      shiny::actionButton("cancel", "Cancel", class = "btn-outline-danger w-100")
    ),
    bslib::layout_columns(
      col_widths = c(7, 5),
      bslib::card(
        bslib::card_header("Retrieval"),
        shiny::uiOutput("size_note"),
        shiny::uiOutput("progress_ui"),
        bslib::accordion(
          open = FALSE,
          bslib::accordion_panel(
            "Live terminal",
            icon = shiny::icon("terminal"),
            shiny::div(
              id = "terminal",
              style = paste(
                "background:#0E2233; color:#E8F1F2; font-family:monospace;",
                "font-size:12px; padding:10px; border-radius:6px; height:280px;",
                "overflow:auto; white-space:pre-wrap;"
              ),
              shiny::uiOutput("terminal_html")
            )
          )
        )
      ),
      bslib::card(
        bslib::card_header("Reproducible code"),
        shiny::p(shiny::tags$small(
          "Everything you do here, as a script you can run in R. The key is read",
          "from your environment, never written below."
        )),
        shiny::verbatimTextOutput("code_mirror"),
        shiny::downloadButton("dl_script", "Download script (.R)",
                              class = "btn-outline-secondary btn-sm")
      )
    ),
    bslib::navset_card_tab(
      title = "Results",
      bslib::nav_panel("Records", shiny::tableOutput("records_table")),
      bslib::nav_panel("By year", shiny::plotOutput("plot_year", height = "320px")),
      bslib::nav_panel("Top sources", shiny::plotOutput("plot_sources", height = "320px")),
      bslib::nav_panel("Top authors", shiny::plotOutput("plot_authors", height = "320px")),
      bslib::nav_panel(
        "Export",
        shiny::br(),
        shiny::p(shiny::tags$small(
          "Carry the records into a reference manager (Zotero, EndNote) or a ",
          "LaTeX bibliography.")),
        shiny::downloadButton("dl_rds", "Records (.rds)", class = "btn-outline-secondary"),
        shiny::downloadButton("dl_dois", "DOIs (.csv)", class = "btn-outline-secondary"),
        shiny::downloadButton("dl_bibtex", "BibTeX (.bib)", class = "btn-outline-secondary"),
        shiny::downloadButton("dl_ris", "RIS (.ris)", class = "btn-outline-secondary")
      )
    ),
    shiny::tags$script(shiny::HTML(
      "window.addEventListener('load', function() {
         var t = document.getElementById('terminal');
         if (!t) return;
         new MutationObserver(function() { t.scrollTop = t.scrollHeight; })
           .observe(t, { childList: true, subtree: true });
       });"
    ))
  )
}

app_server <- function(input, output, session) {
  rv <- shiny::reactiveValues(
    proc = NULL, logfile = NULL, records = NULL, lines = character(),
    progress = NULL, status = "idle"
  )

  # The key lives only in the session, passed to the worker as an argument.
  api_key <- shiny::reactive({
    k <- trimws(input$api_key %||% "")
    if (nzchar(k)) k else NULL
  })

  output$key_status <- shiny::renderUI({
    if (is.null(api_key())) {
      shiny::span(class = "text-warning", shiny::icon("circle"),
                  " Enter your key to fetch.")
    } else {
      shiny::span(class = "text-success", shiny::icon("circle-check"), " Key set.")
    }
  })

  years_value <- shiny::reactive({
    if (isTRUE(input$use_years)) seq(input$years[1], input$years[2]) else NULL
  })

  max_value <- shiny::reactive({
    mr <- suppressWarnings(as.numeric(input$max_results))
    if (length(mr) != 1L || is.na(mr) || mr < 1) Inf else mr
  })

  # The live code mirror, rebuilt whenever the plan inputs change.
  output$code_mirror <- shiny::renderText({
    app_code_mirror(
      query = input$query, years = years_value(),
      field = input$field, view = input$view,
      partition = if (isTRUE(input$use_years)) "year" else "none",
      max_results = max_value()
    )
  })

  # Cheap pre-flight sizing, run synchronously: one request per query/year.
  shiny::observeEvent(input$count, {
    if (is.null(api_key())) {
      shiny::showNotification("Enter your Scopus API key first.", type = "warning")
      return()
    }
    shiny::withProgress(message = "Checking size", value = 0.5, {
      out <- tryCatch(
        scopus_count(input$query, years = years_value(), field = nzchar_or_null(input$field),
                     view = input$view, api_key = api_key()),
        scopus_error = function(e) e
      )
    })
    if (inherits(out, "condition")) {
      rv$status <- "error"
      shiny::showNotification(paste("Scopus:", conditionMessage(out)), type = "error",
                              duration = NULL)
      return()
    }
    n <- as.numeric(out)
    ncells <- if (isTRUE(input$use_years)) length(years_value()) else 1L
    rv$size_note <- sprintf(
      "This query matches %s records across %d %s.",
      format(n, big.mark = ","), ncells, if (ncells == 1L) "cell" else "year-cells"
    )
  })

  output$size_note <- shiny::renderUI({
    if (is.null(rv$size_note)) {
      return(shiny::p(shiny::tags$small(
        "Tip: Check size first to see how much you would retrieve.")))
    }
    shiny::div(class = "alert alert-info py-2", rv$size_note)
  })

  # Launch the background harvest.
  shiny::observeEvent(input$fetch, {
    if (is.null(api_key())) {
      shiny::showNotification("Enter your Scopus API key first.", type = "warning")
      return()
    }
    if (!is.null(rv$proc) && rv$proc$is_alive()) {
      shiny::showNotification("A retrieval is already running.", type = "warning")
      return()
    }
    key <- gsub("[^a-zA-Z0-9]+", "-",
                paste(input$query, input$field, input$view,
                      paste(range(years_value() %||% 0L), collapse = "-")))
    cache_dir <- file.path(tempdir(), "scopusflow-app", substr(key, 1L, 80L))
    dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)
    if (!is.null(rv$logfile) && file.exists(rv$logfile)) unlink(rv$logfile)
    logfile <- tempfile("scopusflow-log-", fileext = ".txt")
    file.create(logfile)

    rv$logfile <- logfile
    rv$lines <- character()
    rv$progress <- NULL
    rv$records <- NULL
    rv$status <- "running"
    rv$proc <- callr::r_bg(
      func = app_fetch_worker,
      args = list(
        query = input$query, years = years_value(),
        field = nzchar_or_null(input$field), view = input$view,
        partition = if (isTRUE(input$use_years)) "year" else "none",
        max_results = max_value(), cache_dir = cache_dir, api_key = api_key()
      ),
      stdout = logfile, stderr = "2>&1", supervise = TRUE
    )
  })

  shiny::observeEvent(input$cancel, {
    if (!is.null(rv$proc) && rv$proc$is_alive()) {
      rv$proc$kill()
      rv$status <- "cancelled"
      rv$progress <- NULL
      if (!is.null(rv$logfile) && file.exists(rv$logfile)) unlink(rv$logfile)
      rv$proc <- NULL
      shiny::showNotification("Retrieval cancelled.", type = "message")
    }
  })

  # Poll the worker: tail the log, update progress, and harvest the result when
  # the process finishes. Guarding only on the process handle (set to NULL on
  # every terminal path) is what stops the timer.
  shiny::observe({
    if (is.null(rv$proc)) {
      return()
    }
    shiny::invalidateLater(750, session)
    if (!is.null(rv$logfile) && file.exists(rv$logfile)) {
      lines <- tryCatch(readLines(rv$logfile, warn = FALSE), error = function(e) NULL)
      if (!is.null(lines)) {
        rv$lines <- lines
        prog <- app_parse_cell_progress(lines)
        if (!is.null(prog)) rv$progress <- prog
      }
    }
    if (!rv$proc$is_alive()) {
      res <- tryCatch(rv$proc$get_result(), error = function(e) e)
      rv$proc <- NULL
      if (inherits(res, "condition")) {
        rv$status <- "error"
        shiny::showNotification(paste("Retrieval did not complete:", conditionMessage(res)),
                                type = "error", duration = NULL)
      } else {
        rv$records <- res
        rv$status <- "done"
        shiny::showNotification(sprintf("Retrieved %s records.",
                                        format(nrow(res), big.mark = ",")), type = "message")
      }
    }
  })

  output$terminal_html <- shiny::renderUI({
    if (length(rv$lines) == 0L) {
      return(shiny::HTML("<span style='opacity:.6'>Background output appears here.</span>"))
    }
    shiny::HTML(app_ansi_to_html(rv$lines))
  })

  output$progress_ui <- shiny::renderUI({
    if (!identical(rv$status, "running")) {
      return(NULL)
    }
    prog <- rv$progress
    if (is.null(prog)) {
      label <- "Working..."
      cls <- "progress-bar progress-bar-striped progress-bar-animated"
      width <- "100%"
      pct_label <- NULL
    } else {
      # "Cell k/N" is logged as cell k starts, so k - 1 cells are complete; the
      # bar stays animated while the current (k-th) cell is still being fetched.
      completed <- max(prog$done - 1L, 0L)
      pct <- round(100 * completed / max(prog$total, 1L))
      label <- sprintf("Fetching cell %d of %d", prog$done, prog$total)
      if (completed == 0L) {
        cls <- "progress-bar progress-bar-striped progress-bar-animated"
        width <- "100%"
        pct_label <- NULL
      } else {
        cls <- "progress-bar"
        width <- paste0(pct, "%")
        pct_label <- paste0(pct, "%")
      }
    }
    shiny::div(
      shiny::tags$small(label),
      shiny::div(
        class = "progress", style = "height:20px;",
        shiny::div(class = cls, role = "progressbar",
                   style = sprintf("width:%s;", width), pct_label)
      )
    )
  })

  records_r <- shiny::reactive(rv$records)

  output$records_table <- shiny::renderTable({
    recs <- records_r()
    shiny::validate(shiny::need(!is.null(recs), "Fetch records to see them here."))
    out <- as.data.frame(recs)[, intersect(c("title", "year", "publication", "citations"),
                                            names(recs)), drop = FALSE]
    utils::head(out, 25L)
  })

  output$plot_year <- shiny::renderPlot({
    recs <- records_r()
    shiny::validate(shiny::need(!is.null(recs), "Fetch records to plot them."),
                    shiny::need(rlang::is_installed("ggplot2"), "Install ggplot2 to see plots."))
    ggplot2::autoplot(recs)
  })

  output$plot_sources <- shiny::renderPlot({
    recs <- records_r()
    shiny::validate(shiny::need(!is.null(recs), "Fetch records to plot them."),
                    shiny::need(rlang::is_installed("ggplot2"), "Install ggplot2 to see plots."))
    plot_scopus_top(scopus_top(recs, by = "source"))
  })

  output$plot_authors <- shiny::renderPlot({
    recs <- records_r()
    shiny::validate(shiny::need(!is.null(recs), "Fetch records to plot them."),
                    shiny::need(rlang::is_installed("ggplot2"), "Install ggplot2 to see plots."))
    plot_scopus_top(scopus_top(recs, by = "author"))
  })

  output$dl_script <- shiny::downloadHandler(
    filename = "scopusflow-script.R",
    content = function(file) {
      writeLines(app_code_mirror(
        query = input$query, years = years_value(), field = input$field,
        view = input$view, partition = if (isTRUE(input$use_years)) "year" else "none",
        max_results = max_value()
      ), file)
    }
  )

  output$dl_rds <- shiny::downloadHandler(
    filename = "scopus-records.rds",
    content = function(file) {
      shiny::req(rv$records)
      write_scopus_records(rv$records, file)
    }
  )

  output$dl_dois <- shiny::downloadHandler(
    filename = "scopus-dois.csv",
    content = function(file) {
      shiny::req(rv$records)
      scopus_extract_dois(rv$records, file = file)
    }
  )

  output$dl_bibtex <- shiny::downloadHandler(
    filename = "scopus-records.bib",
    content = function(file) {
      shiny::req(rv$records)
      as_bibtex(rv$records, file = file)
    }
  )

  output$dl_ris <- shiny::downloadHandler(
    filename = "scopus-records.ris",
    content = function(file) {
      shiny::req(rv$records)
      as_ris(rv$records, file = file)
    }
  )

  # Stop the worker and clean up the worker's logfile and cache when the browser
  # session ends, so no search terms linger on disk.
  session$onSessionEnded(function() {
    p <- shiny::isolate(rv$proc)
    if (!is.null(p) && p$is_alive()) try(p$kill(), silent = TRUE)
    lf <- shiny::isolate(rv$logfile)
    if (!is.null(lf) && file.exists(lf)) try(unlink(lf), silent = TRUE)
    try(unlink(file.path(tempdir(), "scopusflow-app"), recursive = TRUE), silent = TRUE)
  })
}

nzchar_or_null <- function(x) {
  if (is.null(x) || !nzchar(x)) NULL else x
}

#' Launch the scopusflow app
#'
#' Starts a local, code-free Shiny app for building a search, retrieving records
#' and exporting them, with a live terminal that streams the retrieval's progress
#' and a panel that mirrors every choice as runnable R code. The app runs on your
#' own machine: your API key never leaves it, and requests originate from your own
#' network, which is what the 'Scopus' API expects. It needs the suggested
#' packages \pkg{shiny}, \pkg{bslib} and \pkg{callr} (and \pkg{ggplot2} for the
#' plots, \pkg{fansi} for coloured terminal output).
#'
#' @param host The address to listen on. Defaults to `"127.0.0.1"`, so the app is
#'   reachable only from your own machine and the key is never exposed on the
#'   network.
#' @param port The port to listen on, or `NULL` (default) to choose one.
#' @param launch.browser Logical, whether to open a browser. Passed to
#'   [shiny::runApp()].
#' @return Called for its side effect of running the app; does not return until
#'   the app is closed.
#' @seealso [scopus_plan()], [scopus_fetch_plan()]
#' @examples
#' \dontrun{
#' run_app()
#' }
#' @export
run_app <- function(host = "127.0.0.1", port = NULL, launch.browser = TRUE) {
  rlang::check_installed(
    c("shiny", "bslib", "callr"),
    reason = "to run the scopusflow app"
  )
  app <- shiny::shinyApp(ui = app_ui(), server = app_server)
  shiny::runApp(app, host = host, port = port, launch.browser = launch.browser)
}
