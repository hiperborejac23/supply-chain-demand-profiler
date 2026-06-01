# SC Demand Profiler & Segmentation Tool
| **Version:** 1.0-draft |
| **Author:** Miloš Milošević |
| **Date:** June 2026 |
---

## 1. Problem Statement
Supply chain planning teams managing large SKU portfolios consistently apply uniform replenishment and forecasting logic across fundamentally different demand patterns. This causes:
- Overstock on slow/intermittent movers (cash tied up, SMOG risk)
- Stockouts on fast movers (service failures, lost revenue)
- Forecast methods applied to wrong demand profiles (Croston needed, SES applied)
- No structured basis for portfolio rationalization decisions

**Target users:** Supply chain planners, operations analysts, PLM teams, S&OP facilitators managing portfolios of 100-10,000+ SKUs.
---

## 2. Solution Overview
A Python-based analytical tool that:
1. Ingests SKU-level demand history (CSV/Excel)
2. Classifies every SKU by demand profile (ADI/CV methodology)
3. Segments the portfolio (ABC/XYZ + K-Means clustering)
4. Compares forecast methods vs. demand profiles
5. Flags SMOG and rationalization risk
6. Delivers results via interactive Streamlit dashboard
---

## 3. Architecture Decisions
### 3.1 Why SQLite (not MySQL/PostgreSQL)
| Factor | Decision | Rationale |
|---|---|---|
| Deployment | SQLite | Zero server dependency - runs anywhere, deploys to Streamlit Cloud |
| Portfolio use | SQLite | People can clone and run locally in 60 seconds |
| Skill signal | SQLite | Schema design, normalization, indexing - same concepts, no infrastructure noise |
| Future scale | Swappable | SQLAlchemy abstraction layer allows upgrade to PostgreSQL without rewriting core logic |

### 3.2 Why Streamlit (not Dash or some BI tool)
- Public deployment via Streamlit Cloud - shareable URL, no login required
- Python-native - no context switch from analytical code
- Supports CSV upload, parameter sliders, multi-page navigation
- Plotly charts embed natively
- Deployable from GitHub in 3 clicks

### 3.3 Why long-format demand table
Demand history stored as `(sku_id, period, demand_qty)` tuples rather than wide pivot tables because:
- Supports variable history lengths per SKU
- Enables efficient time-series queries
- Scales to any number of periods without schema changes
- Standard pattern for BI tools and pandas time-series operations
---

## 4. Data Model
### 4.1 Input specification
**Minimum required columns:**
| Column | Type | Notes |
|---|---|---|
| `sku_id` | string | Unique identifier |
| `sku_name` | string | Display name |
| `period` | YYYY-MM | Monthly granularity |
| `demand_qty` | float | Quantity demanded |
| `revenue` | float | Revenue value |

**Optional columns** (unlock additional features):
| Column | Feature unlocked |
|---|---|
| `forecast_qty` | Forecast comparison module |
| `category` | Category-level aggregation |
| `brand` | Brand-level segmentation |
| `lifecycle_status` | Rationalization flags |
| `warehouse_id` | Multi-warehouse SMOG |

### 4.2 Database schema (data/schema.sql)
Key tables:
- `upload_runs` - audit trail of every analysis run
- `skus` - master SKU dimension
- `demand_history` - append-only fact table
- `demand_profiles` - ADI/CV output per run
- `abc_xyz_segments` - segmentation output per run
- `clustering_results` - K-Means output per run
- `smog_scores` - risk scoring output (v1.2)
- `run_config` - parameter snapshot for reproducibility
---

## 5. Core Module Specifications
### 5.1 core/profiler.py
**Inputs:**
- `demand_df`: DataFrame with columns `[sku_id, period, demand_qty]`
- `adi_threshold`: float, default 1.32
- `cv2_threshold`: float, default 0.49
- `analysis_window`: int (months), default 24

**Outputs:**
DataFrame with columns:
```
sku_id | adi | cv_squared | demand_mean | demand_std |
active_periods | total_periods | demand_profile |
recommended_method | periods_since_last_demand |
is_new_product | seasonality_flag
```

**Core logic to implement:**
```python
# ADI = total_periods / count(periods where demand > 0)
# CV² = variance(non_zero_demand) / mean(non_zero_demand)²
# Profile assignment: 2x2 matrix on ADI/CV² thresholds
# Recommended method mapping:
#   Smooth      → 'SES'
#   Erratic     → 'SES_dampened'
#   Intermittent→ 'Croston'
#   Lumpy       → 'SBA'
```

**Validation:** Run against synthetic data where ground truth profile is known. Target ≥ 85% classification match.
---

### 5.2 core/segmentation.py
**Inputs:**
- `demand_df`: demand history
- `profile_df`: output from profiler
- `abc_a_cutoff`: 0.80
- `abc_b_cutoff`: 0.95
- `xyz_x_cutoff`: 0.50
- `xyz_y_cutoff`: 1.00
- `k_clusters`: int, default 5

**Outputs:**
- `abc_xyz_df`: DataFrame with abc_class, xyz_class, segment columns
- `cluster_df`: DataFrame with cluster_id, cluster_label, silhouette_score

**ABC logic:**
```python
# Sort by total revenue descending
# Calculate cumulative revenue %
# Assign A/B/C by cutoff thresholds
```

**XYZ logic:**
```python
# Calculate CV of periodic demand per SKU (not CV²)
# Assign X/Y/Z by cutoff thresholds
```

**K-Means logic:**
```python
# Features: [adi, cv_squared, demand_mean_normalized,
#            revenue_pct, active_periods_pct]
# Standardize with StandardScaler before fitting
# Select k using elbow + silhouette (test k=2..8)
# Label clusters descriptively from centroid analysis
```
---

### 5.3 core/db.py
**Key functions to implement:**
```python
def get_connection(db_path: str) -> sqlite3.Connection
def init_db(conn) -> None          # runs schema.sql
def insert_run(conn, meta) -> int  # returns run_id
def update_skus(conn, df) -> None
def insert_demand(conn, df, run_id) -> None
def save_profiles(conn, df, run_id) -> None
def save_segments(conn, df, run_id) -> None
def save_clusters(conn, df, run_id) -> None
def get_latest_run(conn) -> dict
def get_run_history(conn) -> pd.DataFrame
```
---

### 5.4 core/pipeline.py - Orchestration
```python
def run_pipeline(filepath, config, db_path) -> dict:
    # 1. Load and validate input file
    # 2. Open DB connection, init schema
    # 3. Register upload run
    # 4. Insert/Update SKUs to dimension table
    # 5. Insert demand history
    # 6. Run profiler → save results
    # 7. Run segmentation → save results
    # 8. Run clustering → save results
    # 9. Return summary dict for UI
```
---

## 6. Streamlit UI Specification
### Page structure
```
app/
├── main.py              ← landing page + navigation
└── pages/
    ├── 01_upload.py     ← file upload, validation, run pipeline
    ├── 02_profiling.py  ← ADI/CV results, profile distribution
    ├── 03_segmentation.py ← ABC/XYZ matrix, K-Means clusters
    ├── 04_forecasting.py  ← still ideate
    └── 05_rationalization.py ← still ideate
```

### Key UI components per page
**01_upload.py:**
- File uploader (CSV/Excel)
- Column mapping dropdowns (if column names differ from spec)
- Validation summary (row count, period range, missing values)
- Run pipeline button
- Success/error feedback
**02_profiling.py:**
- Profile distribution donut chart (Smooth/Erratic/Intermittent/Lumpy counts)
- ADI vs CV² scatter plot - colored by profile
- SKU-level data table with filter/search
- Parameter sliders (ADI threshold, CV² threshold) - re-runs classification live

**03_segmentation.py:**
- ABC/XYZ heatmap matrix (3×3 with SKU counts per cell)
- K-Means cluster visualization (PCA-reduced 2D scatter)
- Elbow curve + silhouette scores
- Cluster profile table (centroid characteristics)
- SKU-level segment assignments table
---

## 7. Development Phases & Timeline
### v0.1 - Core (Week 1-2 from June 1)
| Week | Focus | Deliverables |
|---|---|---|
| 1 | Foundation | GitHub setup, README public, generator working, schema tested, db.py complete |
| 2 | Core engines | profiler.py complete + tested, segmentation.py complete + tested |
| 3 | UI + deploy | Streamlit pages 01-03, Streamlit Cloud deployment, README screenshots |

**v0.1 ships:** ~June 10

### v0.2 - Forecasting (Weeks 2-3)
| Week | Focus | Deliverables |
|---|---|---|
| 4 | Forecasting engine | core/forecasting.py: SES, Croston, SBA implementations |
| 5 | Forecast UI | Page 04, accuracy metrics, model comparison charts |

**v1.1 ships:** ~June 20

### v1.2 - SMOG + Rationalization (Weeks 3-4)
| Week | Focus | Deliverables |
|---|---|---|
| 6 | SMOG engine | core/smog.py, rationalization flag logic |
| 7 | Rationalization UI | Page 05, export to CSV, portfolio action list |

**v1.2 ships:** ~July 1
---

## 8. Testing Strategy
### Unit tests (tests/)
- `test_profiler.py`: Known demand series → assert correct ADI, CV², profile
- `test_segmentation.py`: Known revenue distribution → assert correct ABC class
- `test_pipeline.py`: End-to-end run on synthetic data → assert DB state

### Validation approach
- Run profiler on synthetic data where `demand_profile_true` is known
- Calculate classification accuracy per profile type
- Target: overall accuracy ≥ 85%, Smooth/Lumpy recall ≥ 90%
---

## 9. Deployment
### Streamlit Cloud setup
1. Connect repo to share.streamlit.io
2. Set entry point: `app/main.py`
3. Requirements: `requirements.txt`
4. SQLite DB path: use `Path(__file__).parent.parent / "data" / "profiler.db"`

### Demo mode
- If no file uploaded → auto-load `data/sample/sample_skus.csv`
- Allows people to explore without needing their own data
---
