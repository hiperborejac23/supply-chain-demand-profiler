-- ============================================================
-- SC Demand Profiler - SQLite Schema
-- Version: 1.0
-- ============================================================

-- RAW INPUT LAYER
-- Stores every uploaded file as a run, preserving history
CREATE TABLE IF NOT EXISTS upload_runs (
    run_id          INTEGER PRIMARY KEY AUTOINCREMENT,
    uploaded_at     TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    filename        TEXT NOT NULL,
    row_count       INTEGER,
    period_min      TEXT,   -- earliest period in upload (YYYY-MM)
    period_max      TEXT,   -- latest period in upload (YYYY-MM)
    notes           TEXT
);

-- MASTER SKU DIMENSION
-- One row per unique SKU - updated on each upload run
CREATE TABLE IF NOT EXISTS skus (
    sku_id          TEXT PRIMARY KEY,
    sku_name        TEXT NOT NULL,
    category        TEXT,
    brand           TEXT,
    lifecycle_status TEXT CHECK(lifecycle_status IN (
                        'active', 'inactive', 'to_be_obsolete',
                        'new', 'unknown'
                    )) DEFAULT 'unknown',
    warehouse_id    TEXT,
    unit_cost       REAL,
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- DEMAND HISTORY FACT TABLE
-- One row per SKU per period - append-only historical record
CREATE TABLE IF NOT EXISTS demand_history (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    sku_id          TEXT NOT NULL REFERENCES skus(sku_id),
    period          TEXT NOT NULL,   -- YYYY-MM
    demand_qty      REAL DEFAULT 0,
    revenue         REAL DEFAULT 0,
    forecast_qty    REAL,            -- optional: demand planner forecast if available
    run_id          INTEGER REFERENCES upload_runs(run_id),
    UNIQUE(sku_id, period)           -- prevent duplicate period entries
);

-- DEMAND PROFILE RESULTS
-- Output of ADI/CV profiling engine - one row per SKU per run
CREATE TABLE IF NOT EXISTS demand_profiles (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    run_id          INTEGER NOT NULL REFERENCES upload_runs(run_id),
    sku_id          TEXT NOT NULL REFERENCES skus(sku_id),
    profiled_at     TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    -- ADI/CV metrics
    adi             REAL,    -- Average Demand Interval
    cv_squared      REAL,    -- Squared Coefficient of Variation
    demand_mean     REAL,    -- Mean of non-zero demand periods
    demand_std      REAL,    -- Std dev of non-zero demand periods
    active_periods  INTEGER, -- Count of periods with demand > 0
    total_periods   INTEGER, -- Total periods in analysis window

    -- Classification output
    demand_profile  TEXT CHECK(demand_profile IN (
                        'Smooth', 'Erratic', 'Intermittent', 'Lumpy'
                    )),
    recommended_method TEXT,  -- e.g. 'SES', 'Croston', 'SBA'

    -- Lifecycle signals
    periods_since_last_demand INTEGER,
    is_new_product  BOOLEAN DEFAULT FALSE,  -- fewer than 6 periods history
    seasonality_flag BOOLEAN DEFAULT FALSE,  -- detected seasonal pattern

    UNIQUE(run_id, sku_id)
);

-- ABC/XYZ SEGMENTATION RESULTS
CREATE TABLE IF NOT EXISTS abc_xyz_segments (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    run_id          INTEGER NOT NULL REFERENCES upload_runs(run_id),
    sku_id          TEXT NOT NULL REFERENCES skus(sku_id),
    segmented_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    -- ABC metrics
    total_revenue   REAL,
    revenue_pct     REAL,    -- % of total portfolio revenue
    cumulative_pct  REAL,    -- cumulative % for ABC cutoff
    abc_class       TEXT CHECK(abc_class IN ('A', 'B', 'C')),

    -- XYZ metrics
    demand_cv       REAL,    -- CV of periodic demand (not squared)
    xyz_class       TEXT CHECK(xyz_class IN ('X', 'Y', 'Z')),

    -- Combined segment
    segment         TEXT,    -- e.g. 'AX', 'BY', 'CZ'
    planning_recommendation TEXT,

    UNIQUE(run_id, sku_id)
);

-- ANALYSIS CONFIGURATION LOG
-- Stores parameter choices per run for reproducibility
CREATE TABLE IF NOT EXISTS run_config (
    run_id          INTEGER PRIMARY KEY REFERENCES upload_runs(run_id),
    adi_threshold   REAL DEFAULT 1.32,
    cv2_threshold   REAL DEFAULT 0.49,
    abc_a_cutoff    REAL DEFAULT 0.80,   -- cumulative % for A class
    abc_b_cutoff    REAL DEFAULT 0.95,   -- cumulative % for B class
    xyz_x_cutoff    REAL DEFAULT 0.50,   -- CV threshold for X
    xyz_y_cutoff    REAL DEFAULT 1.00   -- CV threshold for Y
  );

-- ── INDEXES FOR QUERY PERFORMANCE ────────────────────────────
CREATE INDEX IF NOT EXISTS idx_demand_history_sku
    ON demand_history(sku_id);
CREATE INDEX IF NOT EXISTS idx_demand_history_period
    ON demand_history(period);
CREATE INDEX IF NOT EXISTS idx_profiles_run
    ON demand_profiles(run_id);
CREATE INDEX IF NOT EXISTS idx_segments_run
    ON abc_xyz_segments(run_id);
