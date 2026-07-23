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

# The demo worker simulates a harvest in a fresh background session: it streams
# per-cell progress (so the live terminal and progress bar behave exactly as in a
# real run) and returns the records it was handed. Those come from the bundled
# corpus and are drawn in the parent (by app_demo_records()) and passed in, so
# the worker needs no package on the child. Mirrors the Python app's
# _demo_worker.
app_demo_fetch_worker <- function(query, years, records) {
  options(cli.num_colors = 256L, cli.default_num_colors = 256L, crayon.enabled = TRUE)
  yrs <- if (is.null(years)) 0L else years
  total <- length(yrs)
  for (i in seq_along(yrs)) {
    cat(sprintf("Cell %d/%d: demo records for %s (%s)\n", i, total, query, yrs[i]))
    flush(stdout())
    Sys.sleep(0.5)
  }
  records
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
      shiny::checkboxInput("demo", "Demo mode (no key needed)", value = TRUE),
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
        "Compare topics",
        # fillable = FALSE so the content flows normally and the plot keeps its
        # fixed height; in a fillable (flex) tab the plot shares height with the
        # inputs and collapses to nothing ("figure margins too large").
        bslib::card_body(
          fillable = FALSE,
          shiny::p(shiny::tags$small(
            "How sub-topics co-occur with your search over time, as a share of it.",
            "Your search terms above are the reference topic.")),
          shiny::textInput("cmp_terms", "Comparison terms (comma-separated)",
                           value = "machine learning, deep learning", width = "100%"),
          bslib::layout_columns(
            col_widths = c(5, 7),
            shiny::selectInput("cmp_highlight", "Highlight topic",
                               choices = c("(none)" = "")),
            shiny::div(
              shiny::checkboxInput("cmp_interval", "Stability band", value = TRUE),
              shiny::checkboxInput("cmp_counts", "Counts in label", value = TRUE)
            )
          ),
          shiny::uiOutput("cmp_note"),
          shiny::actionButton("compare", "Compare topics",
                              class = "btn-outline-primary mb-2",
                              icon = shiny::icon("chart-line")),
          shiny::plotOutput("plot_comparison", height = "360px"),
          shiny::br(),
          shiny::downloadButton("dl_comparison", "Comparison (.csv)",
                                class = "btn-outline-secondary btn-sm")
        )
      ),
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
    progress = NULL, status = "idle", comparison = NULL
  )

  # The key lives only in the session, passed to the worker as an argument.
  api_key <- shiny::reactive({
    k <- trimws(input$api_key %||% "")
    if (nzchar(k)) k else NULL
  })

  output$key_status <- shiny::renderUI({
    if (isTRUE(input$demo)) {
      shiny::span(class = "text-info", shiny::icon("flask"),
                  " Demo mode: synthetic data, no key needed.")
    } else if (is.null(api_key())) {
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
    # A blank or invalid entry means "all"; a fractional entry is floored so the
    # worker and the generated script agree on a whole-number cap.
    if (length(mr) != 1L || is.na(mr) || mr < 1) Inf else floor(mr)
  })

  # Comma-separated comparison terms, parsed once for the plot, the count note,
  # the CSV download and the reproducible script. Duplicates are dropped so a
  # repeated term does not spend a redundant count request or double a legend.
  cmp_terms_value <- shiny::reactive({
    raw <- trimws(strsplit(input$cmp_terms %||% "", ",", fixed = TRUE)[[1]])
    unique(raw[nzchar(raw)])
  })

  # The live code mirror, rebuilt whenever the plan or comparison inputs change,
  # and shared by the on-screen panel and the script download.
  code_text <- shiny::reactive({
    app_code_mirror(
      query = input$query, years = years_value(),
      field = input$field, view = input$view,
      partition = if (isTRUE(input$use_years)) "year" else "none",
      max_results = max_value(),
      compare_terms = cmp_terms_value(),
      highlight = if (nzchar(input$cmp_highlight %||% "")) input$cmp_highlight else NULL,
      interval = !identical(input$cmp_interval, FALSE),
      pub_count_in_legend = !identical(input$cmp_counts, FALSE)
    )
  })

  output$code_mirror <- shiny::renderText(code_text())

  # Cheap pre-flight sizing, run synchronously: one request per query/year.
  shiny::observeEvent(input$count, {
    if (isTRUE(input$demo)) {
      ncells <- if (isTRUE(input$use_years)) length(years_value()) else 1L
      # Derived from the same function the demo harvest uses, since each year of
      # the bundled corpus holds a different number of records.
      nrecs <- nrow(app_demo_records(
        if (isTRUE(input$use_years)) years_value() else NULL,
        max_per_year = max_value()
      ))
      rv$size_note <- sprintf(
        "Demo plan: %d %s; would draw %d records from the bundled corpus.",
        ncells, if (ncells == 1L) "cell" else "year-cells", nrecs)
      return()
    }
    if (is.null(api_key())) {
      shiny::showNotification("Enter your Scopus API key, or switch on Demo mode.",
                              type = "warning")
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
    if (!isTRUE(input$demo) && is.null(api_key())) {
      shiny::showNotification("Enter your Scopus API key, or switch on Demo mode.",
                              type = "warning")
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
    rv$proc <- if (isTRUE(input$demo)) {
      callr::r_bg(
        func = app_demo_fetch_worker,
        args = list(query = input$query, years = years_value(),
                    records = app_demo_records(years_value(),
                                               max_per_year = max_value())),
        stdout = logfile, stderr = "2>&1", supervise = TRUE
      )
    } else {
      callr::r_bg(
        func = app_fetch_worker,
        args = list(
          query = input$query, years = years_value(),
          field = nzchar_or_null(input$field), view = input$view,
          partition = if (isTRUE(input$use_years)) "year" else "none",
          max_results = max_value(), cache_dir = cache_dir, api_key = api_key()
        ),
        stdout = logfile, stderr = "2>&1", supervise = TRUE
      )
    }
  })

  shiny::observeEvent(input$cancel, {
    if (!is.null(rv$proc) && rv$proc$is_alive()) {
      rv$proc$kill()
      rv$status <- "cancelled"
      rv$progress <- NULL
      if (!is.null(rv$logfile) && file.exists(rv$logfile)) unlink(rv$logfile)
      rv$proc <- NULL
      shiny::showNotification("Retrieval cancelled.", type = "message")
    } else {
      shiny::showNotification("Nothing to cancel.", type = "message")
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
    content = function(file) writeLines(code_text(), file)
  )

  # Topic comparison. The highlight choices track the entered terms; the note
  # shows the count-request cost (one per term per year) outside demo mode.
  shiny::observeEvent(cmp_terms_value(), {
    terms <- cmp_terms_value()
    sel <- if (!is.null(input$cmp_highlight) && input$cmp_highlight %in% terms) {
      input$cmp_highlight
    } else {
      ""
    }
    shiny::updateSelectInput(session, "cmp_highlight",
                             choices = c("(none)" = "", terms), selected = sel)
  }, ignoreNULL = FALSE)

  output$cmp_note <- shiny::renderUI({
    terms <- cmp_terms_value()
    if (length(terms) == 0L || isTRUE(input$demo)) {
      return(NULL)
    }
    this_year <- as.integer(format(Sys.Date(), "%Y"))
    yrs <- years_value() %||% seq(this_year - 5L, this_year)
    n <- length(terms) * length(yrs)
    msg <- sprintf(
      "%d term%s x %d year%s = %d count requests.%s",
      length(terms), if (length(terms) == 1L) "" else "s",
      length(yrs), if (length(yrs) == 1L) "" else "s", n,
      if (n > 80L) "  Consider fewer terms or years." else ""
    )
    shiny::p(shiny::tags$small(msg))
  })

  shiny::observeEvent(input$compare, {
    if (!nzchar(trimws(input$query %||% ""))) {
      shiny::showNotification("Enter search terms first (used as the reference topic).",
                              type = "warning")
      return()
    }
    terms <- cmp_terms_value()
    if (length(terms) == 0L) {
      shiny::showNotification("Enter at least one comparison term.", type = "warning")
      return()
    }
    if (!isTRUE(input$demo) && is.null(api_key())) {
      shiny::showNotification("Enter your Scopus API key, or switch on Demo mode.",
                              type = "warning")
      return()
    }
    # A comparison issues count requests on the same key as a harvest, and runs
    # synchronously, so block it while a background fetch is in flight.
    if (!is.null(rv$proc) && rv$proc$is_alive()) {
      shiny::showNotification("Wait for the retrieval to finish before comparing.",
                              type = "warning")
      return()
    }
    this_year <- as.integer(format(Sys.Date(), "%Y"))
    yrs <- years_value() %||% seq(this_year - 5L, this_year)
    # One count step per term, plus the reference: drive a live progress bar.
    n_steps <- length(terms) + 1L

    out <- shiny::withProgress(message = "Comparing topics", value = 0, {
      if (isTRUE(input$demo)) {
        # Synthesise with visible per-term progress so the demo shows activity.
        shiny::setProgress(1L / n_steps, detail = "counting the reference")
        Sys.sleep(0.4)
        for (i in seq_along(terms)) {
          shiny::setProgress((i + 1L) / n_steps,
                             detail = sprintf("counting '%s'", terms[i]))
          Sys.sleep(0.4)
        }
        app_demo_comparison(input$query, terms, yrs)
      } else {
        # Advance the bar on each verbose message scopus_compare_topics emits
        # (one per count step), so a long term x year grid is observable.
        step <- 0L
        withCallingHandlers(
          # Catch any failure, not only a typed scopus_error, so a network or
          # internal error surfaces as a notification rather than a red screen.
          tryCatch(
            scopus_compare_topics(input$query, terms, years = yrs,
                                  field = nzchar_or_null(input$field),
                                  view = input$view, api_key = api_key(),
                                  verbose = TRUE),
            error = function(e) e
          ),
          message = function(m) {
            step <<- step + 1L
            shiny::setProgress(min(step / n_steps, 1),
                               detail = trimws(conditionMessage(m)))
            invokeRestart("muffleMessage")
          }
        )
      }
    })
    if (inherits(out, "condition")) {
      msg <- if (inherits(out, "scopus_error")) {
        paste("Scopus:", conditionMessage(out))
      } else {
        paste("Comparison failed:", conditionMessage(out))
      }
      shiny::showNotification(msg, type = "error", duration = NULL)
      return()
    }
    rv$comparison <- out
  })

  output$plot_comparison <- shiny::renderPlot({
    cmp <- rv$comparison
    shiny::validate(
      shiny::need(!is.null(cmp), "Enter comparison terms and click Compare topics."),
      shiny::need(rlang::is_installed("ggplot2"), "Install ggplot2 to see the plot.")
    )
    topics <- unique(cmp$abridged_query[cmp$query_type == "comparison"])
    hl <- input$cmp_highlight
    if (is.null(hl) || !nzchar(hl) || !hl %in% topics) hl <- NULL
    plot_scopus_comparison(
      cmp, highlight = hl, interval = !identical(input$cmp_interval, FALSE),
      pub_count_in_legend = !identical(input$cmp_counts, FALSE)
    )
  })

  output$dl_comparison <- shiny::downloadHandler(
    filename = "scopus-comparison.csv",
    content = function(file) {
      shiny::req(rv$comparison)
      utils::write.csv(as.data.frame(rv$comparison), file, row.names = FALSE)
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
#' Starts a local, code-free Shiny app for building a search, retrieving records,
#' comparing topic trends and exporting the results, with a live terminal that
#' streams the retrieval's progress and a panel that mirrors every choice as
#' runnable R code. A *Demo mode* (on by default) draws records from the bundled
#' [example_records] corpus and synthesises a topic comparison, so the whole
#' workflow can be explored with no key and no network;
#' switch it off and supply a key to query 'Scopus' for real. The app runs on your
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
