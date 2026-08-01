import streamlit as st
import psycopg
import pandas as pd

st.set_page_config(page_title="BRVM — Cours du jour", layout="wide")

DATABASE_URL = st.secrets["DATABASE_URL"]


@st.cache_resource
def get_connection():
    return psycopg.connect(DATABASE_URL)


@st.cache_data(ttl=300)
def load_cotations():
    conn = get_connection()
    return pd.read_sql("""
        SELECT DISTINCT ON (t.symbole)
            t.symbole, t.nom, c.date, c."coursCloture", c."variationPct", c.volume
        FROM "Cotation" c
        JOIN "Titre" t ON t.id = c."titreId"
        ORDER BY t.symbole, c.date DESC
    """, conn)


@st.cache_data(ttl=300)
def load_indices():
    conn = get_connection()
    return pd.read_sql("""
        SELECT DISTINCT ON (code) code, date, valeur, "variationPct"
        FROM "IndiceQuotidien"
        ORDER BY code, date DESC
    """, conn)


st.title("📈 Cours BRVM")

indices = load_indices()
if not indices.empty:
    cols = st.columns(len(indices))
    for col, (_, row) in zip(cols, indices.iterrows()):
        delta = f"{row['variationPct']:+.2f}%" if pd.notna(row["variationPct"]) else None
        col.metric(row["code"], f"{row['valeur']:.2f}", delta)
else:
    st.info("Pas encore d'indices en base.")

st.divider()

cotations = load_cotations()
if cotations.empty:
    st.info("Pas encore de cours en base.")
else:
    recherche = st.text_input("Filtrer par symbole ou nom")
    if recherche:
        mask = (
            cotations["symbole"].str.contains(recherche, case=False, na=False)
            | cotations["nom"].str.contains(recherche, case=False, na=False)
        )
        cotations = cotations[mask]

    st.dataframe(
        cotations.rename(columns={
            "symbole": "Symbole", "nom": "Nom", "coursCloture": "Clôture (FCFA)",
            "variationPct": "Variation (%)", "volume": "Volume", "date": "Date",
        }),
        use_container_width=True, hide_index=True,
    )

st.caption("Données mises à jour manuellement pour l'instant.")
