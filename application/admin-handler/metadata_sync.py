"""
metadata_sync.py

Implementerer "Synk-prosess" (avsnitt 3) i arkitektur_qc_object_annotations.md.

Hoerer sannsynligvis hjemme i application/admin-handler/ (eller en ny
metadata-handler), sammen med endepunktene skissert i avsnitt 6:

    POST /admin/metadata/annotations
        -> hent eksisterende rad (hvis update), valider, kall
           apply_annotation(cursor, new_row, old_row), oppdater
           qc_object_annotations, commit.

Designprinsipper:
  - sync_target='NONE'           -> ingen DDL, kun lagring i tabellen
  - sync_target='COMMENT'        -> COMMENT ON TABLE/COLUMN ... IS '...'
  - sync_target='ANNOTATION'     -> ALTER TABLE ... [MODIFY <col>] ANNOTATIONS (...)
  - status-overganger inn/ut av 'AKTIV' utloeser ADD/DROP (ANNOTATION) eller
    sett/tom streng (COMMENT) - se build_ddl_statements().
  - object_owner/object_name/column_name valideres mot ALL_TABLES/
    ALL_VIEWS/ALL_TAB_COLUMNS foer DDL genereres (defense in depth -
    admin-UI skal allerede begrense til kjente objekter).
"""

import re

VALID_SYNC_TARGETS = {"COMMENT", "ANNOTATION", "NONE"}
VALID_STATUSES = {"AKTIV", "UTKAST", "ARKIVERT"}

# Enkelt identifikator: bokstav/understreng foerst, deretter
# bokstaver/tall/_/$/#  (standard Oracle-regler for unquoted identifiers).
_IDENT_RE = re.compile(r"^[A-Za-z_][A-Za-z0-9_$#]*$")

# Annotation_name kan inneholde mellomrom (f.eks. "JOIN COLUMN"), men
# ellers samme regler som identifikatorer.
_ANNOTATION_NAME_RE = re.compile(r"^[A-Za-z_][A-Za-z0-9_ ]*$")


class AnnotationSyncError(Exception):
    """Reises ved ugyldig input eller DDL-generering som ikke kan utfoeres trygt."""


def _escape_literal(value: str) -> str:
    """Escaper enkle fnutter for bruk i en SQL-strengliteral."""
    return value.replace("'", "''")


def _quote_ident(name: str) -> str:
    """
    Kvoter en databaseidentifikator (owner/tabell/kolonne) til
    "STORE_BOKSTAVER"-form. Forutsetter at navnet allerede er validert
    mot dictionary-views av kalleren (validate_object_reference).
    """
    if not _IDENT_RE.match(name):
        raise AnnotationSyncError(f"Ugyldig identifikatornavn: {name!r}")
    return f'"{name.upper()}"'


def _quote_annotation_name(name: str) -> str:
    """
    Formaterer annotation_name for ANNOTATIONS-klausulen.

    Flerords-navn (f.eks. "JOIN COLUMN") MA dobbelt-kvotes i DDL-en.
    Enkeltords-navn emittes ukvotert, i tråd med Oracles offisielle
    eksempler (DESCRIPTION, ALIASES, UNITS).
    """
    if not _ANNOTATION_NAME_RE.match(name):
        raise AnnotationSyncError(f"Ugyldig annotation_name: {name!r}")
    if " " in name:
        return f'"{name}"'
    return name


def validate_object_reference(cursor, owner, table_name, column_name=None):
    """
    Bekrefter at objektet (og evt. kolonnen) faktisk finnes, foer DDL
    genereres. Reiser AnnotationSyncError hvis ikke funnet.

    Stotter baade tabeller og views (KI_GRUNNLAG_*-tabeller er TABLE,
    men fremtidige metadata-maal kan vaere VIEW).
    """
    cursor.execute(
        """
        SELECT
          (SELECT COUNT(*) FROM all_tables
            WHERE owner = :owner AND table_name = :table_name)
          +
          (SELECT COUNT(*) FROM all_views
            WHERE owner = :owner AND view_name = :table_name)
        FROM dual
        """,
        owner=owner.upper(),
        table_name=table_name.upper(),
    )
    if cursor.fetchone()[0] == 0:
        raise AnnotationSyncError(
            f"Objekt {owner}.{table_name} finnes ikke (ALL_TABLES/ALL_VIEWS)"
        )

    if column_name is not None:
        cursor.execute(
            """
            SELECT COUNT(*) FROM all_tab_columns
            WHERE owner = :owner AND table_name = :table_name
              AND column_name = :column_name
            """,
            owner=owner.upper(),
            table_name=table_name.upper(),
            column_name=column_name.upper(),
        )
        if cursor.fetchone()[0] == 0:
            raise AnnotationSyncError(
                f"Kolonne {owner}.{table_name}.{column_name} finnes ikke"
            )


def _validate_row(row):
    sync_target = row.get("sync_target")
    status = row.get("status")
    if sync_target not in VALID_SYNC_TARGETS:
        raise AnnotationSyncError(f"Ugyldig sync_target: {sync_target!r}")
    if status not in VALID_STATUSES:
        raise AnnotationSyncError(f"Ugyldig status: {status!r}")
    if sync_target == "ANNOTATION" and not row.get("annotation_name"):
        raise AnnotationSyncError(
            "annotation_name er paakrevd for sync_target='ANNOTATION'"
        )
    if sync_target == "NONE" and not row.get("notat_type"):
        raise AnnotationSyncError("notat_type er paakrevd for sync_target='NONE'")
    if not row.get("annotation_value"):
        raise AnnotationSyncError("annotation_value kan ikke vaere tom")


def _comment_target_clause(owner, obj, col):
    if col:
        return (
            f"COMMENT ON COLUMN {_quote_ident(owner)}."
            f"{_quote_ident(obj)}.{_quote_ident(col)}"
        )
    return f"COMMENT ON TABLE {_quote_ident(owner)}.{_quote_ident(obj)}"


def build_ddl_statements(new_row, old_row=None):
    """
    Returnerer en liste med DDL-strenger som maa kjores for aa bringe
    databasen i samsvar med new_row, gitt forrige tilstand old_row
    (None hvis dette er en ny rad / ingen tidligere AKTIV tilstand).

    Returnerer [] hvis ingen DDL er nodvendig:
      - sync_target='NONE'
      - status-overgang som ikke involverer AKTIV i det hele tatt
        (f.eks. UTKAST -> UTKAST, eller UTKAST -> ARKIVERT uten at
        raden noensinne ble publisert)

    For sync_target='ANNOTATION' genereres DROP+ADD i SAMME
    ALTER TABLE-setning ved oppdatering av en allerede-AKTIV rad
    (annotations stotter ikke REPLACE direkte). Hvis annotation_name
    endres mellom old_row og new_row, droppes det GAMLE navnet og
    det NYE legges til.
    """
    _validate_row(new_row)

    target = new_row["sync_target"]
    if target == "NONE":
        return []

    was_active = old_row is not None and old_row.get("status") == "AKTIV"
    is_active = new_row["status"] == "AKTIV"

    owner = new_row["object_owner"]
    obj = new_row["object_name"]
    col = new_row.get("column_name")

    if target == "COMMENT":
        if is_active:
            value = _escape_literal(new_row["annotation_value"])
            return [f"{_comment_target_clause(owner, obj, col)} IS '{value}'"]
        if was_active:
            # Forlater AKTIV: fjern kommentaren vi tidligere satte.
            # NB: setter til tom streng (Oracle-konvensjon for aa
            # nullstille en COMMENT), paavirker ikke andre kommentarer.
            return [f"{_comment_target_clause(owner, obj, col)} IS ''"]
        return []

    if target == "ANNOTATION":
        clauses = []

        if was_active and is_active:
            # Samme annotasjonsnavn: bruk REPLACE (Oracle tillater ikke DROP+ADD
            # av samme navn i én setning - ORA-11602)
            old_name = _quote_annotation_name(old_row["annotation_name"])
            new_name = _quote_annotation_name(new_row["annotation_name"])
            if old_name == new_name:
                value = _escape_literal(new_row["annotation_value"])
                clauses.append(f"REPLACE {new_name} '{value}'")
            else:
                # Ulikt navn: DROP gammelt + ADD nytt er OK (forskjellige navn)
                clauses.append(f"DROP {old_name}")
                value = _escape_literal(new_row["annotation_value"])
                clauses.append(f"ADD {new_name} '{value}'")

        elif was_active and not is_active:
            # AKTIV -> ARKIVERT/UTKAST: kun DROP
            old_name = _quote_annotation_name(old_row["annotation_name"])
            clauses.append(f"DROP {old_name}")

        elif not was_active and is_active:
            # Ny eller UTKAST -> AKTIV: kun ADD
            new_name = _quote_annotation_name(new_row["annotation_name"])
            value = _escape_literal(new_row["annotation_value"])
            clauses.append(f"ADD {new_name} '{value}'")

        if not clauses:
            return []

        annotations_clause = "ANNOTATIONS (" + ", ".join(clauses) + ")"

        if col:
            return [
                f"ALTER TABLE {_quote_ident(owner)}.{_quote_ident(obj)} "
                f"MODIFY {_quote_ident(col)} {annotations_clause}"
            ]
        return [
            f"ALTER TABLE {_quote_ident(owner)}.{_quote_ident(obj)} "
            f"{annotations_clause}"
        ]


def apply_annotation(cursor, new_row, old_row=None, execute=True):
    """
    Validerer referansen, genererer DDL via build_ddl_statements, og
    kjorer den (hvis execute=True).

    Returnerer listen med DDL-setninger (utfort eller ikke).

    Kalleren (admin-handler-endepunktet) har ansvar for:
      - aa hente old_row fra qc_object_annotations FOR oppdatering
      - aa skrive/oppdatere raden i qc_object_annotations (id,
        updated_by, updated_at) ETTER at DDL er kjort uten feil
      - transaksjon/commit rundt begge deler
    """
    validate_object_reference(
        cursor,
        new_row["object_owner"],
        new_row["object_name"],
        new_row.get("column_name"),
    )

    statements = build_ddl_statements(new_row, old_row)

    if execute:
        for stmt in statements:
            cursor.execute(stmt)

    return statements


# =====================================================================
# Selvtest / dokumentasjon: viser generert DDL for de konkrete
# eksemplene fra verifiseringsarbeidet (BELOEP-formel, STILLINGSGRUPPE
# IN-liste, ALIASES med "JOIN COLUMN"). Kjor: python metadata_sync.py
# =====================================================================
if __name__ == "__main__":
    examples = []

    # 1. Ny ANNOTATION, tabellnivaa, enkeltords-navn
    examples.append(
        (
            "Ny DESCRIPTION-annotasjon (kolonnenivaa, formel)",
            build_ddl_statements(
                new_row={
                    "object_owner": "querychat",
                    "object_name": "ki_grunnlag_oracle_rdap_hr_mndverk",
                    "column_name": "beloep",
                    "sync_target": "ANNOTATION",
                    "annotation_name": "DESCRIPTION",
                    "annotation_value": (
                        'VIKTIG: For "gjennomsnittslonn" skal AVG(beloep) '
                        "ALDRI brukes. Korrekt formel: SUM(beloep) / "
                        "NULLIF(SUM(maanedsverk_brutto), 0)."
                    ),
                    "status": "AKTIV",
                },
                old_row=None,
            ),
        )
    )

    # 2. Oppdatering av eksisterende ANNOTATION (DROP+ADD i samme ALTER)
    examples.append(
        (
            "Oppdatering av eksisterende STILLINGSGRUPPE-annotasjon",
            build_ddl_statements(
                new_row={
                    "object_owner": "querychat",
                    "object_name": "ki_grunnlag_oracle_rdap_hr_mndverk",
                    "column_name": "stillingsgruppe",
                    "sync_target": "ANNOTATION",
                    "annotation_name": "DESCRIPTION",
                    "annotation_value": (
                        "Bruk stillingsgruppe IN ('Sykepleier', "
                        "'Operasjonssykepleier') for 'sykepleiere totalt'."
                    ),
                    "status": "AKTIV",
                },
                old_row={
                    "annotation_name": "DESCRIPTION",
                    "annotation_value": "Gammel tekst",
                    "status": "AKTIV",
                },
            ),
        )
    )

    # 3. Annotation_name med mellomrom ("JOIN COLUMN")
    examples.append(
        (
            'Tabellnivaa-annotasjon med flerords-navn ("JOIN COLUMN")',
            build_ddl_statements(
                new_row={
                    "object_owner": "querychat",
                    "object_name": "ki_grunnlag_oracle_rdap_bemanning",
                    "column_name": None,
                    "sync_target": "ANNOTATION",
                    "annotation_name": "JOIN COLUMN",
                    "annotation_value": "helseforetak",
                    "status": "AKTIV",
                },
                old_row=None,
            ),
        )
    )

    # 4. Arkivering: AKTIV -> ARKIVERT for en ANNOTATION (kun DROP)
    examples.append(
        (
            "Arkivering av tidligere AKTIV annotasjon",
            build_ddl_statements(
                new_row={
                    "object_owner": "querychat",
                    "object_name": "ki_grunnlag_oracle_rdap_hr_mndverk",
                    "column_name": "stillingsgruppe",
                    "sync_target": "ANNOTATION",
                    "annotation_name": "DESCRIPTION",
                    "annotation_value": "(ikke i bruk lenger)",
                    "status": "ARKIVERT",
                },
                old_row={
                    "annotation_name": "DESCRIPTION",
                    "annotation_value": "Tidligere tekst",
                    "status": "AKTIV",
                },
            ),
        )
    )

    # 5. COMMENT, kolonnenivaa
    examples.append(
        (
            "Ny COMMENT paa kolonnenivaa",
            build_ddl_statements(
                new_row={
                    "object_owner": "querychat",
                    "object_name": "ki_grunnlag_oracle_rdap_liggetimer",
                    "column_name": "poliklinisk_lt",
                    "sync_target": "COMMENT",
                    "annotation_value": (
                        "Polikliniske liggetimer. VARCHAR2 - 11.6% av radene "
                        "er ikke-numeriske (kjent datakvalitetsproblem)."
                    ),
                    "status": "AKTIV",
                },
                old_row=None,
            ),
        )
    )

    # 6. sync_target='NONE' - ingen DDL
    examples.append(
        (
            "Internt notat (sync_target='NONE') - ingen DDL",
            build_ddl_statements(
                new_row={
                    "object_owner": "querychat",
                    "object_name": "ki_grunnlag_oracle_rdap_liggetimer",
                    "column_name": "akuttmottak",
                    "sync_target": "NONE",
                    "annotation_value": "Kjent datakvalitetsproblem, se rapport.",
                    "notat_type": "DATAKVALITET",
                    "status": "AKTIV",
                },
                old_row=None,
            ),
        )
    )

    for title, stmts in examples:
        print(f"\n--- {title} ---")
        if not stmts:
            print("(ingen DDL)")
        for s in stmts:
            print(s)
