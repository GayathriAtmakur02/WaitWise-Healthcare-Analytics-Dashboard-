# ============================================================
# WaitWise Healthcare Analytics — EDA & Data Cleaning
# Author  : Gayathri | Data Analyst
# Dataset : Healthcare Patient Wait List (2018–2021)
# Usage   : python healthcare_eda_cleaning.py --zip_path Data.zip
#           python healthcare_eda_cleaning.py --data_dir ./Data
# Outputs : outputs/cleaned_healthcare_waitlist.csv
#           outputs/eda_summary.txt
#           outputs/*.png
# ============================================================

import re
import zipfile
import argparse
from pathlib import Path
from typing import List, Tuple, Optional

import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import matplotlib.ticker as mticker

# ── Constants ────────────────────────────────────────────────

BLUE_PALETTE = ["#1F4E79", "#2E75B6", "#4A9FD4", "#7EC8E3", "#BDD7EE"]

TIME_BAND_ORDER = {
    "0-3 Months": 1, "3-6 Months": 2, "6-9 Months": 3,
    "9-12 Months": 4, "12-15 Months": 5, "15-18 Months": 6,
    "18+ Months": 7, "Unknown": 99,
}

TIME_BAND_FIXES = {
    "Months +": "Months+", "Month +": "Month+",
    "18 Months+": "18+ Months", "18 Months +": "18+ Months",
    "0- 3 Months": "0-3 Months", "3- 6 Months": "3-6 Months",
    "6- 9 Months": "6-9 Months", "9- 12 Months": "9-12 Months",
    "12- 15 Months": "12-15 Months", "15- 18 Months": "15-18 Months",
}

INPATIENT_PATTERN  = re.compile(r"IN_WL\s*\d{4}\.csv$")
OUTPATIENT_PATTERN = re.compile(r"Op_WL\s*\d{4}\.csv$")
MAPPING_NAME       = "Mapping_Specialty.csv"

# ── File Discovery ───────────────────────────────────────────

def _classify(names):
    """Split file list into data files + mapping file."""
    data    = sorted(n for n in names if INPATIENT_PATTERN.search(str(n)) or OUTPATIENT_PATTERN.search(str(n)))
    mapping = next((n for n in names if MAPPING_NAME in str(n)), None)
    if not mapping:
        raise FileNotFoundError(f"{MAPPING_NAME} not found in source.")
    return data, mapping


def discover_zip(zip_path: Path):
    with zipfile.ZipFile(zip_path) as z:
        return _classify(z.namelist())


def discover_dir(data_dir: Path):
    return _classify(sorted(data_dir.rglob("*.csv")))

# ── Loaders ──────────────────────────────────────────────────

def _read(source, path, from_zip: bool) -> pd.DataFrame:
    if from_zip:
        with zipfile.ZipFile(source) as z:
            with z.open(path) as f:
                return pd.read_csv(f)
    return pd.read_csv(path)


def _normalise_frame(df: pd.DataFrame) -> pd.DataFrame:
    """Align outpatient 'Speciality' column and drop junk columns."""
    if "Speciality" in df.columns:
        df = df.rename(columns={"Speciality": "Specialty_Name"})
        df["Case_Type"] = "Outpatient"
    return df.drop(columns=[c for c in df.columns if c.startswith("Unnamed")], errors="ignore")


def load_raw(zip_path: Optional[Path] = None, data_dir: Optional[Path] = None):
    if zip_path:
        files, mapping_path = discover_zip(zip_path)
        frames     = [_normalise_frame(_read(zip_path, f, from_zip=True)) for f in files]
        mapping_df = _read(zip_path, mapping_path, from_zip=True)
    elif data_dir:
        files, mapping_path = discover_dir(data_dir)
        frames     = [_normalise_frame(_read(None, f, from_zip=False)) for f in files]
        mapping_df = pd.read_csv(mapping_path)
    else:
        raise ValueError("Provide either zip_path or data_dir.")

    print(f"Loaded {len(frames)} file(s).")
    return pd.concat(frames, ignore_index=True), mapping_df

# ── Cleaning Helpers ─────────────────────────────────────────

def _clean_str(s: pd.Series) -> pd.Series:
    return s.astype(str).str.replace(r"\s+", " ", regex=True).str.strip().replace({"nan": np.nan})


def _fix_time_band(val) -> str:
    if pd.isna(val):
        return np.nan
    val = re.sub(r"\s+", " ", str(val)).strip()
    for old, new in TIME_BAND_FIXES.items():
        val = val.replace(old, new)
    return val

# ── Main Clean Function ──────────────────────────────────────

def clean(df: pd.DataFrame, mapping_df: pd.DataFrame) -> pd.DataFrame:
    df         = df.copy()
    mapping_df = mapping_df.copy()

    # Strip column name whitespace
    df.columns         = df.columns.str.strip()
    mapping_df.columns = mapping_df.columns.str.strip()

    # Clean string columns
    for col in ["Specialty_Name", "Case_Type", "Adult_Child", "Age_Profile", "Time_Bands"]:
        if col in df.columns:
            df[col] = _clean_str(df[col])

    for col in ["Specialty", "Specialty Group"]:
        if col in mapping_df.columns:
            mapping_df[col] = _clean_str(mapping_df[col])

    # Parse dates and numerics
    df["Archive_Date"]  = pd.to_datetime(df["Archive_Date"], format="%d-%m-%Y", errors="coerce")
    df["Specialty_HIPE"] = pd.to_numeric(df.get("Specialty_HIPE"), errors="coerce")
    df["Total"]          = pd.to_numeric(df["Total"], errors="coerce")

    # Standardise categorical labels
    df["Time_Bands"] = df["Time_Bands"].apply(_fix_time_band)

    # Fill missing values
    fill_map = {"Adult_Child": "Unknown", "Age_Profile": "Unknown",
                "Time_Bands": "Unknown", "Specialty_Name": "Unknown", "Total": 0}
    for col, val in fill_map.items():
        if col in df.columns:
            df[col] = df[col].fillna(val)

    # Drop duplicates
    before = len(df)
    df = df.drop_duplicates()
    print(f"Duplicates removed: {before - len(df):,}  |  Rows remaining: {len(df):,}")

    # Merge specialty mapping
    if "Specialty" in mapping_df.columns:
        df = df.merge(mapping_df, how="left", left_on="Specialty_Name", right_on="Specialty")
        df["Specialty Group"] = df["Specialty Group"].fillna("Unmapped")
        df = df.drop(columns=["Specialty"], errors="ignore")
    else:
        df["Specialty Group"] = "Unmapped"

    # Derive date features
    df["Year"]        = df["Archive_Date"].dt.year
    df["Month"]       = df["Archive_Date"].dt.month
    df["Month_Name"]  = df["Archive_Date"].dt.strftime("%b")
    df["Year_Month"]  = df["Archive_Date"].dt.to_period("M").astype(str)

    # Time band sort order
    df["Time_Band_Order"] = df["Time_Bands"].map(TIME_BAND_ORDER)

    return df

# ── EDA Summary ──────────────────────────────────────────────

def eda_summary(df: pd.DataFrame) -> str:
    latest_date = df["Archive_Date"].max()
    latest      = df[df["Archive_Date"] == latest_date]

    def section(title):
        return [f"\n{title}", "-" * 60]

    lines = [
        "WAITWISE HEALTHCARE — EDA SUMMARY",
        "=" * 60,
        f"Author      : Gayathri | Data Analyst",
        f"Rows        : {len(df):,}",
        f"Columns     : {df.shape[1]}",
        f"Date range  : {df['Archive_Date'].min().date()} → {df['Archive_Date'].max().date()}",
        f"Specialties : {df['Specialty_Name'].nunique():,}",
        f"Case types  : {', '.join(sorted(df['Case_Type'].dropna().unique()))}",
    ]

    # Missing values
    lines += section("Missing Values (post-cleaning)")
    missing = df.isna().sum()
    missing = missing[missing > 0]
    lines += ([f"  {c}: {v:,}" for c, v in missing.items()] or ["  None detected."])

    # Case type distribution (full history)
    lines += section("Case Type Distribution — All Time")
    for _, r in (df.groupby("Case_Type")["Total"].sum()
                   .sort_values(ascending=False).reset_index().iterrows()):
        lines.append(f"  {r['Case_Type']}: {int(r['Total']):,}")

    # Latest snapshot
    lines += section(f"Latest Snapshot: {latest_date.date()}")
    lines.append(f"  Total wait list: {int(latest['Total'].sum()):,}")
    for _, r in (latest.groupby("Case_Type")["Total"].sum()
                        .sort_values(ascending=False).reset_index().iterrows()):
        lines.append(f"  {r['Case_Type']}: {int(r['Total']):,}")

    # Top 10 specialties
    lines += section("Top 10 Specialties (latest snapshot)")
    top = (latest.groupby("Specialty_Name")["Total"].sum()
                 .sort_values(ascending=False).head(10).reset_index())
    for _, r in top.iterrows():
        lines.append(f"  {r['Specialty_Name']}: {int(r['Total']):,}")

    # Age profile
    lines += section("Age Profile Distribution (latest snapshot)")
    for _, r in (latest.groupby("Age_Profile")["Total"].sum()
                        .sort_values(ascending=False).reset_index().iterrows()):
        lines.append(f"  {r['Age_Profile']}: {int(r['Total']):,}")

    # Time bands
    lines += section("Time Band Distribution (latest snapshot)")
    tb = (latest.groupby(["Time_Bands", "Time_Band_Order"])["Total"].sum()
                .reset_index().sort_values("Time_Band_Order"))
    for _, r in tb.iterrows():
        lines.append(f"  {r['Time_Bands']}: {int(r['Total']):,}")

    # Outlier detection on Total
    lines += section("Outlier Detection — Total (IQR Method)")
    Q1, Q3 = df["Total"].quantile([0.25, 0.75])
    IQR    = Q3 - Q1
    lower, upper = Q1 - 1.5 * IQR, Q3 + 1.5 * IQR
    outliers = df[(df["Total"] < lower) | (df["Total"] > upper)]
    lines += [
        f"  Q1: {Q1:,.2f}  |  Q3: {Q3:,.2f}  |  IQR: {IQR:,.2f}",
        f"  Lower bound : {lower:,.2f}",
        f"  Upper bound : {upper:,.2f}",
        f"  Outlier rows: {len(outliers):,} ({len(outliers)/len(df)*100:.2f}%)",
    ]

    return "\n".join(lines)

# ── Visualisations ───────────────────────────────────────────

def _fmt(ax, axis="y"):
    fmt = mticker.FuncFormatter(lambda x, _: f"{int(x):,}")
    if axis == "y":
        ax.yaxis.set_major_formatter(fmt)
    else:
        ax.xaxis.set_major_formatter(fmt)


def _save(path: Path):
    plt.tight_layout()
    plt.savefig(path, dpi=150, bbox_inches="tight")
    plt.close()


def create_visuals(df: pd.DataFrame, output_dir: Path):
    latest_date = df["Archive_Date"].max()
    latest      = df[df["Archive_Date"] == latest_date].copy()

    # 1. Monthly trend by case type
    trend = (df.groupby(["Archive_Date", "Case_Type"])["Total"]
               .sum().reset_index().sort_values("Archive_Date"))
    fig, ax = plt.subplots(figsize=(12, 5))
    for i, (ct, g) in enumerate(trend.groupby("Case_Type")):
        ax.plot(g["Archive_Date"], g["Total"], marker="o", markersize=3,
                label=ct, color=BLUE_PALETTE[i % len(BLUE_PALETTE)], linewidth=2)
    ax.set_title("Monthly Wait List Trend by Case Type", fontsize=13, fontweight="bold")
    ax.set_ylabel("Patient Count"); ax.legend(title="Case Type"); ax.grid(alpha=0.3)
    _fmt(ax); _save(output_dir / "01_monthly_trend_by_case_type.png")

    # 2. Case type — bar + pie
    case = (latest.groupby("Case_Type")["Total"].sum()
                  .sort_values(ascending=False).reset_index())
    fig, axes = plt.subplots(1, 2, figsize=(12, 5))
    axes[0].bar(case["Case_Type"], case["Total"],
                color=BLUE_PALETTE[:len(case)], edgecolor="white")
    axes[0].set_title(f"Wait List by Case Type\n({latest_date.date()})", fontweight="bold")
    axes[0].set_ylabel("Patient Count"); _fmt(axes[0])
    axes[1].pie(case["Total"], labels=case["Case_Type"], autopct="%1.1f%%",
                colors=BLUE_PALETTE[:len(case)], startangle=90,
                wedgeprops={"edgecolor": "white", "linewidth": 1.5})
    axes[1].set_title("Case Type Share (%)", fontweight="bold")
    plt.suptitle("Case Type Distribution", fontsize=14, fontweight="bold")
    _save(output_dir / "02_case_type_distribution.png")

    # 3. Top 10 specialties
    top = (latest.groupby("Specialty_Name")["Total"].sum()
                 .sort_values().tail(10).reset_index())
    fig, ax = plt.subplots(figsize=(10, 6))
    ax.barh(top["Specialty_Name"], top["Total"], color="#2E75B6", edgecolor="white")
    ax.set_title(f"Top 10 Specialties — Wait List\n({latest_date.date()})", fontweight="bold")
    ax.set_xlabel("Patient Count"); _fmt(ax, axis="x")
    _save(output_dir / "03_top_10_specialties.png")

    # 4. Age profile
    age = (latest.groupby("Age_Profile")["Total"].sum()
                 .sort_values(ascending=False).reset_index())
    fig, ax = plt.subplots(figsize=(8, 4))
    ax.bar(age["Age_Profile"], age["Total"],
           color=BLUE_PALETTE[:len(age)], edgecolor="white")
    ax.set_title(f"Wait List by Age Profile\n({latest_date.date()})", fontweight="bold")
    ax.set_ylabel("Patient Count"); _fmt(ax)
    _save(output_dir / "04_age_profile_distribution.png")

    # 5. Time band distribution
    tb = (latest.groupby(["Time_Bands", "Time_Band_Order"])["Total"].sum()
                .reset_index().sort_values("Time_Band_Order"))
    fig, ax = plt.subplots(figsize=(10, 4))
    ax.bar(tb["Time_Bands"], tb["Total"], color="#1F4E79", edgecolor="white")
    ax.set_title(f"Wait List by Time Band\n({latest_date.date()})", fontweight="bold")
    ax.set_ylabel("Patient Count")
    plt.xticks(rotation=30, ha="right"); _fmt(ax)
    _save(output_dir / "05_time_band_distribution.png")

    # 6. Outlier box + histogram
    fig, axes = plt.subplots(1, 2, figsize=(12, 4))
    axes[0].boxplot(df["Total"], patch_artist=True,
                    boxprops=dict(facecolor="#BDD7EE", color="#1F4E79"),
                    medianprops=dict(color="#1F4E79", linewidth=2),
                    flierprops=dict(marker="o", color="#2E75B6", alpha=0.4))
    axes[0].set_title("Box Plot — Total Wait Count", fontweight="bold")
    axes[0].set_ylabel("Patient Count"); _fmt(axes[0])
    axes[1].hist(df["Total"], bins=40, color="#2E75B6", edgecolor="white")
    axes[1].set_title("Distribution — Total Wait Count", fontweight="bold")
    axes[1].set_xlabel("Patient Count"); axes[1].set_ylabel("Frequency"); _fmt(axes[1], axis="x")
    plt.suptitle("Outlier Detection", fontsize=14, fontweight="bold")
    _save(output_dir / "06_outlier_detection.png")

    print(f"6 charts saved to: {output_dir.resolve()}")

# ── Entry Point ──────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(description="WaitWise — Healthcare EDA & Data Cleaning")
    parser.add_argument("--zip_path",   type=str, default=None, help="Path to Data.zip")
    parser.add_argument("--data_dir",   type=str, default=None, help="Path to extracted Data folder")
    parser.add_argument("--output_dir", type=str, default="outputs", help="Output folder (default: outputs)")
    args = parser.parse_args()

    if not args.zip_path and not args.data_dir:
        raise ValueError("Provide --zip_path or --data_dir.")

    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    zip_path  = Path(args.zip_path)  if args.zip_path  else None
    data_dir  = Path(args.data_dir)  if args.data_dir  else None

    # Load → Clean → Summarise → Visualise → Export
    raw_df, mapping_df = load_raw(zip_path=zip_path, data_dir=data_dir)
    cleaned_df         = clean(raw_df, mapping_df)
    summary            = eda_summary(cleaned_df)

    cleaned_csv  = output_dir / "cleaned_healthcare_waitlist.csv"
    summary_path = output_dir / "eda_summary.txt"

    cleaned_df.to_csv(cleaned_csv, index=False)
    summary_path.write_text(summary, encoding="utf-8")
    create_visuals(cleaned_df, output_dir)

    print(summary)
    print(f"\nCleaned data  → {cleaned_csv}")
    print(f"EDA summary   → {summary_path}")


if __name__ == "__main__":
    main()
