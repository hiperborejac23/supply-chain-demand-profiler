"""
app/main.py - SC Demand Profiler Landing Page
"""
import streamlit as st

st.set_page_config(
    page_title="SC Demand Profiler",
    page_icon="📦",
    layout="wide",
    initial_sidebar_state="expanded",
)

st.title("📦 SC Demand Profiler & Segmentation Tool")
st.caption("Supply chain portfolio intelligence - demand profiling · ABC/XYZ · K-Means segmentation")

st.markdown("---")

col1, col2, col3 = st.columns(3)

with col1:
    st.metric("Demand Profiles", "4 types", "Smooth · Erratic · Intermittent · Lumpy")

with col2:
    st.metric("Segmentation Methods", "2 layers", "ABC/XYZ + K-Means clustering")

with col3:
    st.metric("Portfolio Actions", "Rationalization flags", "Active · Inactive · Obsolete")

st.markdown("---")
st.markdown("""
### How to use this tool

1. **Upload** your SKU demand history (CSV or Excel) on the Upload page
2. **Explore** demand profiles - see how your portfolio classifies across ADI/CV² space
3. **Segment** your portfolio - ABC/XYZ matrix and behavioral clusters
4. **Act** - use the rationalization flags to drive PLM and S&OP decisions

> *Don't have your own data?* The tool loads a synthetic demo dataset automatically.
Navigate to **Upload** to get started.
""")
