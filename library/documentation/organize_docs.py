#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
organize_docs.py - agente di riordino per la cartella documentation.

Idea
----
La cartella contiene documenti LaTeX (.tex + .pdf compilato), modelli Simscape
(.ssc), script Python/MATLAB e dati, tutti appiattiti nella root. Il
sottoprogetto gia' ordinato `div_load_model` definisce la struttura target:

    <progetto>/
        <progetto>.tex
        <progetto>.pdf
        README.md
        ssc/
        py/
        matlab/
        fig/
        data/

Lo script raggruppa i file in progetti e li sposta in quella struttura.
Il raggruppamento puo' essere fatto in due modi:

  * modalita' AI (default se ANTHROPIC_API_KEY e' definita): un agente Claude
    legge l'elenco dei file e propone i gruppi. Serve perche' i nomi non sono
    sempre allineati - p.es. `tvs_clamp.ssc` appartiene al documento
    `active_clamping_5SNA1000G650300.tex`, cosa che nessuna regola sui nomi
    puo' indovinare.
  * modalita' euristica (--no-ai, oppure fallback): raggruppa per radice comune
    del nome file.

In entrambi i casi il piano viene validato (nessun file perso, nessuna
sovrascrittura) e mostrato prima di toccare qualsiasi cosa.

Uso
---
    python organize_docs.py                 # anteprima (dry-run), non muove nulla
    python organize_docs.py --apply         # esegue lo spostamento
    python organize_docs.py --no-ai         # solo euristica sui nomi
    python organize_docs.py --undo          # annulla l'ultimo --apply
    python organize_docs.py --plan piano.json --apply   # usa un piano gia' revisionato

Opzioni utili: --dir <cartella>, --model <modello>, --save-plan <file.json>.
Lo script non cancella mai niente: sposta e basta, e scrive un manifest
`.organize_manifest.json` che permette di tornare indietro con --undo.
"""

from __future__ import annotations

import argparse
import json
import os
import shutil
import sys
from pathlib import Path
from typing import Dict, List, Optional, Tuple

# --------------------------------------------------------------------------
# configurazione
# --------------------------------------------------------------------------

MANIFEST_NAME = ".organize_manifest.json"
DEFAULT_MODEL = os.environ.get("ANTHROPIC_MODEL", "claude-sonnet-4-5")

# estensione -> sottocartella ("" = radice del progetto)
SUBDIR_BY_EXT: Dict[str, str] = {
    ".tex": "",
    ".pdf": "",
    ".md": "",
    ".ssc": "ssc",
    ".sscp": "ssc",
    ".slx": "matlab",
    ".m": "matlab",
    ".mat": "matlab",
    ".mlx": "matlab",
    ".py": "py",
    ".ipynb": "py",
    ".csv": "data",
    ".json": "data",
    ".txt": "data",
    ".dat": "data",
    ".xlsx": "data",
    ".png": "fig",
    ".jpg": "fig",
    ".jpeg": "fig",
    ".svg": "fig",
    ".eps": "fig",
    ".ai": "fig",
}

# file che restano dove sono
IGNORED_NAMES = {MANIFEST_NAME, "README.md", "organize_docs.py", ".gitignore"}

# estensioni di scarto della compilazione LaTeX: non vengono spostate
AUX_EXTS = {".aux", ".log", ".out", ".toc", ".lof", ".lot", ".synctex.gz",
            ".fls", ".fdb_latexmk", ".bbl", ".blg", ".nav", ".snm", ".vrb"}


# --------------------------------------------------------------------------
# scansione
# --------------------------------------------------------------------------

def scan(root: Path) -> Tuple[List[Path], List[Path]]:
    """Ritorna (file nella root da riordinare, sottocartelle gia' esistenti)."""
    files, dirs = [], []
    for p in sorted(root.iterdir()):
        if p.is_dir():
            if not p.name.startswith("."):
                dirs.append(p)
            continue
        if p.name in IGNORED_NAMES or p.name.startswith("."):
            continue
        if p.suffix.lower() in AUX_EXTS or "".join(p.suffixes[-2:]).lower() in AUX_EXTS:
            continue
        files.append(p)
    return files, dirs


# --------------------------------------------------------------------------
# raggruppamento euristico (fallback, e base del prompt per l'AI)
# --------------------------------------------------------------------------

_STRIP_SUFFIXES = ("_doc", "_model", "_note", "_documentation", "_report")


def _normalize_stem(stem: str) -> str:
    s = stem.lower()
    # via i suffissi numerici di versione: foo_1, foo_v2
    parts = s.split("_")
    while len(parts) > 1 and (parts[-1].isdigit() or
                              (parts[-1].startswith("v") and parts[-1][1:].isdigit())):
        parts.pop()
    s = "_".join(parts)
    for suf in _STRIP_SUFFIXES:
        if s.endswith(suf) and len(s) > len(suf) + 2:
            s = s[: -len(suf)]
    return s.strip("_")


def heuristic_groups(files: List[Path]) -> Dict[str, List[str]]:
    """Raggruppa per radice del nome, poi fonde le radici che sono prefisso
    l'una dell'altra (igbt_simple_2th -> igbt_simple)."""
    buckets: Dict[str, List[str]] = {}
    for f in files:
        buckets.setdefault(_normalize_stem(f.stem), []).append(f.name)

    keys = sorted(buckets, key=len)
    merged: Dict[str, List[str]] = {}
    for k in keys:
        target = None
        for m in merged:
            if k.startswith(m + "_") or m.startswith(k + "_"):
                target = m
                break
        if target is None:
            merged[k] = list(buckets[k])
        else:
            merged[target].extend(buckets[k])

    # secondo giro: fonde i gruppi che condividono un primo token "distintivo",
    # cioe' che contiene cifre (un codice disegno / part number come hs778746).
    # Token generici come "igbt" o "mos" non fondono nulla.
    by_token: Dict[str, List[str]] = {}
    for k in merged:
        tok = k.split("_")[0]
        if any(c.isdigit() for c in tok) and len(tok) >= 4:
            by_token.setdefault(tok, []).append(k)
    for tok, ks in by_token.items():
        if len(ks) < 2:
            continue
        # il nome buono e' quello del gruppo che contiene il documento
        docs = [k for k in ks
                if any(f.lower().endswith((".tex", ".pdf")) for f in merged[k])]
        keep = min(docs or ks, key=len)
        for k in ks:
            if k != keep:
                merged[keep].extend(merged.pop(k))

    return {k: sorted(v) for k, v in merged.items()}


# --------------------------------------------------------------------------
# agente AI
# --------------------------------------------------------------------------

PLAN_TOOL = {
    "name": "propose_plan",
    "description": "Propone il raggruppamento dei file in progetti.",
    "input_schema": {
        "type": "object",
        "properties": {
            "groups": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "name": {
                            "type": "string",
                            "description": "nome cartella, snake_case, senza estensione",
                        },
                        "description": {
                            "type": "string",
                            "description": "una riga in inglese, per il README",
                        },
                        "files": {
                            "type": "array",
                            "items": {"type": "string"},
                            "description": "nomi file esatti come forniti",
                        },
                    },
                    "required": ["name", "description", "files"],
                },
            },
            "unassigned": {
                "type": "array",
                "items": {"type": "string"},
                "description": "file da lasciare nella root perche' non chiaramente attribuibili",
            },
        },
        "required": ["groups", "unassigned"],
    },
}

SYSTEM_PROMPT = """\
Sei un assistente che riordina una cartella di documentazione tecnica di
elettronica di potenza. Contiene note LaTeX (.tex con il .pdf compilato),
modelli Simscape (.ssc), script Python e MATLAB, dati e figure.

Raggruppa i file per ARGOMENTO, non solo per nome: un modello .ssc appartiene
al documento .tex che lo descrive anche quando i nomi non coincidono
(p.es. un modello di clamp TVS appartiene alla nota sull'active clamping).
Usa la tua conoscenza di elettronica di potenza per capire i legami.

Regole:
- ogni file fornito compare esattamente una volta, fra groups e unassigned;
- non inventare nomi di file: usa esattamente quelli dati;
- nome cartella: snake_case corto e parlante, derivato dal documento principale;
- un gruppo con un solo file va bene se il file e' autonomo; se invece non sai
  dove metterlo, mettilo in unassigned;
- non creare gruppi contenitore generici tipo "misc" o "altri".
Rispondi chiamando lo strumento propose_plan."""


def ai_groups(files: List[Path], existing_dirs: List[Path],
              model: str) -> Optional[Dict]:
    try:
        import anthropic  # type: ignore
    except ImportError:
        print("[ai] pacchetto 'anthropic' non installato "
              "(pip install anthropic) -> uso l'euristica.")
        return None
    if not os.environ.get("ANTHROPIC_API_KEY"):
        print("[ai] ANTHROPIC_API_KEY non impostata -> uso l'euristica.")
        return None

    listing = "\n".join(f"- {f.name} ({f.stat().st_size} byte)" for f in files)
    existing = ", ".join(d.name for d in existing_dirs) or "(nessuna)"
    hint = json.dumps(heuristic_groups(files), indent=2, ensure_ascii=False)

    user_msg = (
        f"Sottocartelle gia' presenti (NON toccarle, servono da esempio di "
        f"struttura): {existing}\n\n"
        f"File da riordinare:\n{listing}\n\n"
        f"Raggruppamento grezzo per sola somiglianza di nome, da usare come "
        f"spunto e da correggere dove sbagliato:\n{hint}\n"
    )

    print(f"[ai] interrogo {model} ...")
    client = anthropic.Anthropic()
    resp = client.messages.create(
        model=model,
        max_tokens=4000,
        system=SYSTEM_PROMPT,
        tools=[PLAN_TOOL],
        tool_choice={"type": "tool", "name": "propose_plan"},
        messages=[{"role": "user", "content": user_msg}],
    )
    for block in resp.content:
        if getattr(block, "type", None) == "tool_use" and block.name == "propose_plan":
            return block.input
    print("[ai] nessun piano restituito -> uso l'euristica.")
    return None


# --------------------------------------------------------------------------
# validazione e costruzione delle mosse
# --------------------------------------------------------------------------

def validate_plan(plan: Dict, files: List[Path]) -> List[str]:
    """Ritorna la lista degli errori trovati (vuota = piano valido)."""
    errors: List[str] = []
    available = {f.name for f in files}
    seen: Dict[str, str] = {}

    for g in plan.get("groups", []):
        name = (g.get("name") or "").strip()
        if not name:
            errors.append("gruppo senza nome")
            continue
        if any(c in name for c in '/\\:*?"<>|'):
            errors.append(f"nome cartella non valido: {name!r}")
        for fn in g.get("files", []):
            if fn not in available:
                errors.append(f"file inesistente nel piano: {fn!r} (gruppo {name})")
            elif fn in seen:
                errors.append(f"file {fn!r} assegnato due volte "
                              f"({seen[fn]} e {name})")
            else:
                seen[fn] = name

    for fn in plan.get("unassigned", []):
        if fn not in available:
            errors.append(f"file inesistente fra gli unassigned: {fn!r}")
        elif fn in seen:
            errors.append(f"file {fn!r} sia in un gruppo sia fra gli unassigned")
        else:
            seen[fn] = "(root)"

    missing = available - set(seen)
    if missing:
        errors.append("file non considerati dal piano: " + ", ".join(sorted(missing)))
    return errors


def build_moves(root: Path, plan: Dict) -> List[Tuple[Path, Path]]:
    """Traduce il piano in una lista di (sorgente, destinazione)."""
    moves: List[Tuple[Path, Path]] = []
    targets: Dict[Path, Path] = {}

    for g in plan.get("groups", []):
        gdir = root / g["name"]
        for fn in sorted(g.get("files", [])):
            src = root / fn
            sub = SUBDIR_BY_EXT.get(src.suffix.lower(), "misc")
            dst = (gdir / sub / fn) if sub else (gdir / fn)
            if dst.exists():
                raise RuntimeError(f"la destinazione esiste gia': {dst}")
            if dst in targets:
                raise RuntimeError(f"due file finirebbero in {dst}")
            targets[dst] = src
            moves.append((src, dst))
    return moves


def write_readme(root: Path, plan: Dict, moves: List[Tuple[Path, Path]]) -> List[str]:
    """Scrive un README.md per progetto. Ritorna i percorsi creati."""
    by_group: Dict[str, List[Path]] = {}
    for _, dst in moves:
        by_group.setdefault(dst.relative_to(root).parts[0], []).append(dst)

    created: List[str] = []
    for g in plan.get("groups", []):
        gdir = root / g["name"]
        readme = gdir / "README.md"
        if readme.exists() or not gdir.is_dir():
            continue
        lines = [f"# {g['name']}", "", g.get("description", "").strip(), "", "## Files", ""]
        for dst in sorted(by_group.get(g["name"], [])):
            lines.append(f"- `{dst.relative_to(gdir).as_posix()}`")
        lines.append("")
        readme.write_text("\n".join(lines), encoding="utf-8")
        created.append(readme.relative_to(root).as_posix())
    return created


# --------------------------------------------------------------------------
# esecuzione
# --------------------------------------------------------------------------

def print_plan(root: Path, plan: Dict, moves: List[Tuple[Path, Path]]) -> None:
    by_group: Dict[str, List[Tuple[Path, Path]]] = {}
    for src, dst in moves:
        by_group.setdefault(dst.relative_to(root).parts[0], []).append((src, dst))

    for g in plan.get("groups", []):
        items = by_group.get(g["name"], [])
        print(f"\n{g['name']}/   -- {g.get('description', '').strip()}")
        for src, dst in sorted(items, key=lambda t: str(t[1])):
            print(f"    {src.name:<52} ->  {dst.relative_to(root).as_posix()}")

    un = plan.get("unassigned", [])
    if un:
        print("\nlasciati nella root:")
        for fn in sorted(un):
            print(f"    {fn}")


def apply_moves(root: Path, moves: List[Tuple[Path, Path]]) -> None:
    manifest = []
    try:
        for src, dst in moves:
            dst.parent.mkdir(parents=True, exist_ok=True)
            shutil.move(str(src), str(dst))
            manifest.append({"from": str(src.relative_to(root).as_posix()),
                             "to": str(dst.relative_to(root).as_posix())})
    finally:
        if manifest:
            (root / MANIFEST_NAME).write_text(
                json.dumps({"moves": manifest}, indent=2), encoding="utf-8")


def undo(root: Path) -> int:
    mf = root / MANIFEST_NAME
    if not mf.exists():
        print(f"nessun manifest in {root}: niente da annullare.")
        return 1
    data = json.loads(mf.read_text(encoding="utf-8"))

    # prima i README generati dallo script (non erano li' prima)
    for rel in data.get("readmes", []):
        p = root / rel
        if p.exists():
            p.unlink()

    restored = 0
    for m in reversed(data.get("moves", [])):
        src, dst = root / m["to"], root / m["from"]
        if not src.exists():
            print(f"  manca {m['to']}, salto")
            continue
        if dst.exists():
            print(f"  {m['from']} esiste gia', salto")
            continue
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.move(str(src), str(dst))
        restored += 1
    # via le cartelle rimaste vuote, ma solo quelle create dallo script
    made = {m["to"].split("/")[0] for m in data.get("moves", [])}
    for top in made:
        base = root / top
        if not base.is_dir():
            continue
        for d in sorted(base.rglob("*"), key=lambda p: len(p.parts), reverse=True):
            if d.is_dir() and not any(d.iterdir()):
                d.rmdir()
        if not any(base.iterdir()):
            base.rmdir()
    mf.unlink()
    print(f"ripristinati {restored} file.")
    return 0


# --------------------------------------------------------------------------

def main() -> int:
    ap = argparse.ArgumentParser(description="Riordina la cartella documentation.")
    ap.add_argument("--dir", default=str(Path(__file__).resolve().parent),
                    help="cartella da riordinare (default: quella dello script)")
    ap.add_argument("--apply", action="store_true",
                    help="esegue davvero gli spostamenti (default: solo anteprima)")
    ap.add_argument("--no-ai", action="store_true",
                    help="salta l'agente AI, usa solo l'euristica sui nomi")
    ap.add_argument("--model", default=DEFAULT_MODEL, help="modello Claude da usare")
    ap.add_argument("--plan", help="carica un piano JSON gia' revisionato")
    ap.add_argument("--save-plan", help="salva il piano proposto su file JSON")
    ap.add_argument("--no-readme", action="store_true",
                    help="non generare i README.md di progetto")
    ap.add_argument("--undo", action="store_true", help="annulla l'ultimo --apply")
    args = ap.parse_args()

    root = Path(args.dir).resolve()
    if not root.is_dir():
        print(f"cartella inesistente: {root}")
        return 2

    if args.undo:
        return undo(root)

    files, dirs = scan(root)
    print(f"cartella : {root}")
    print(f"file     : {len(files)} da riordinare")
    print(f"gia' ok  : {', '.join(d.name for d in dirs) or '(nessuna sottocartella)'}")
    if not files:
        print("niente da fare.")
        return 0

    if args.plan:
        plan = json.loads(Path(args.plan).read_text(encoding="utf-8"))
        print(f"piano caricato da {args.plan}")
    else:
        plan = None if args.no_ai else ai_groups(files, dirs, args.model)
        if plan is None:
            plan = {
                "groups": [{"name": k, "description": "", "files": v}
                           for k, v in sorted(heuristic_groups(files).items())],
                "unassigned": [],
            }

    errors = validate_plan(plan, files)
    if errors:
        print("\npiano NON valido:")
        for e in errors:
            print("  - " + e)
        return 3

    try:
        moves = build_moves(root, plan)
    except RuntimeError as e:
        print(f"\npiano non applicabile: {e}")
        return 3

    print_plan(root, plan, moves)

    if args.save_plan:
        Path(args.save_plan).write_text(
            json.dumps(plan, indent=2, ensure_ascii=False), encoding="utf-8")
        print(f"\npiano salvato in {args.save_plan}")

    if not args.apply:
        print(f"\n--- ANTEPRIMA: nessun file spostato. "
              f"Rilancia con --apply per eseguire. ---")
        return 0

    apply_moves(root, moves)
    if not args.no_readme:
        created = write_readme(root, plan, moves)
        mf = root / MANIFEST_NAME
        data = json.loads(mf.read_text(encoding="utf-8"))
        data["readmes"] = created
        mf.write_text(json.dumps(data, indent=2), encoding="utf-8")
    print(f"\nfatto: {len(moves)} file spostati. "
          f"Per tornare indietro: python {Path(__file__).name} --undo")
    return 0


if __name__ == "__main__":
    sys.exit(main())
