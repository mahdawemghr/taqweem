#!/usr/bin/env python3
"""Generate lib/data/shia_occasions.dart from docs/shia-occasions/research/months-*.json
plus the curated convention layer docs/shia-occasions/convention.json (the
user's own calendar scans define the CONVENTION; see R24/R25).

Run from the repo root:  python3 -I tool/gen_shia_occasions.py
Options:  --out DIR          write shia_occasions.dart + DATA-SUMMARY.md into DIR
          --convention PATH  use another convention file (tests)
"""
import argparse
import glob
import json
import os
import re
import sys
from urllib.parse import urlparse

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RESEARCH = os.path.join(ROOT, "docs", "shia-occasions", "research")
OUT_DART = os.path.join(ROOT, "lib", "data", "shia_occasions.dart")
OUT_MD = os.path.join(ROOT, "docs", "shia-occasions", "DATA-SUMMARY.md")
CONVENTION = os.path.join(ROOT, "docs", "shia-occasions", "convention.json")
SCANS = os.path.join(ROOT, "docs", "shia-occasions", "user-calendar-scans.json")

DENYLIST = ["معاوية", "الحرب العالمية", "الخميني", "السيستاني", "الخوئي",
            "مطهري", "بهجت", "الصدر"]
USER_CAL = "user-calendar"
USER_CAL_NAME = "تقويم أهل البيت (المرجع)"
# shaaer.ir and saraer.org are the same magazine -> one family.
FAMILY_ALIASES = {"shaaer.ir": "shaaer", "saraer.org": "shaaer"}
# alkafeel.net = shrine-forum reposts: counts as a family but never alone
# with another weak family; a verified entry needs a non-weak family too.
WEAK_FAMILIES = {"alkafeel.net"}
FAMILY_NAMES = {
    "wikishia.net": "ويكي شيعة",
    "alkafeel.net": "العتبة العباسية",
    "wikifeqh.ir": "ويكي فقه",
    "imam-us.org": "مكتب السيد السيستاني",
    "al-islam.org": "al-islam.org",
    "shaaer": "مجلة شعائر",
    "almaaref.org": "المعارف الحكيمة",
    USER_CAL: USER_CAL_NAME,
}
SCAN_URL = re.compile(r"^user-calendar://user-calendar-scans\.json#(\d{1,2})-(\d{4})-d(\d{1,2})$")
CATEGORIES = {"birth", "martyrdom", "eid", "battle", "event", "night", "other"}
STRIP_PREFIXES = ("www.", "ar.", "fa.", "en.")
MONTHS_AR = ["محرم", "صفر", "ربيع الأول", "ربيع الثاني", "جمادى الأول",
             "جمادى الثانية", "رجب", "شعبان", "رمضان", "شوال", "ذو القعدة",
             "ذو الحجة"]

errors = []
warnings = []


def err(msg):
    errors.append(msg)


def family(url):
    if url.startswith("user-calendar://"):
        return USER_CAL
    host = (urlparse(url).hostname or "").lower()
    changed = True
    while changed:
        changed = False
        for p in STRIP_PREFIXES:
            if host.startswith(p):
                host = host[len(p):]
                changed = True
    labels = [x for x in host.split(".") if x]
    fam = ".".join(labels[-2:]) if len(labels) >= 2 else host
    return FAMILY_ALIASES.get(fam, fam)


def dart_str(s):
    s = (s.replace("\\", "\\\\").replace("'", "\\'").replace("$", "\\$")
          .replace("\r", "\\r").replace("\n", "\\n"))
    return "'" + s + "'"


def load():
    files = sorted(glob.glob(os.path.join(RESEARCH, "months-*.json")))
    if len(files) != 4:
        err("expected 4 research JSON files, found %d" % len(files))
    entries = []
    for f in files:
        name = os.path.basename(f)
        try:
            with open(f, encoding="utf-8") as fh:
                data = json.load(fh)
        except Exception as e:  # noqa
            err("%s: cannot parse JSON: %s" % (name, e))
            continue
        for m in data.get("months", []):
            mo = m.get("month")
            for i, o in enumerate(m.get("occasions", [])):
                where = "%s month=%s #%d" % (name, mo, i)
                if not isinstance(mo, int) or not 1 <= mo <= 12:
                    err("%s: bad month %r" % (where, mo))
                    continue
                day = o.get("day")
                if not isinstance(day, int) or isinstance(day, bool) or not 1 <= day <= 30:
                    err("%s: bad day %r" % (where, day))
                title = (o.get("titleAr") or "").strip()
                if not title:
                    err("%s: empty titleAr" % where)
                variant = o.get("variant")
                if variant not in ("main", "alternate"):
                    err("%s (%s): bad variant %r" % (where, title, variant))
                conf = o.get("confidence")
                if conf not in ("high", "medium"):
                    err("%s (%s): bad confidence %r" % (where, title, conf))
                srcs = o.get("sources")
                if not isinstance(srcs, list) or not srcs:
                    err("%s (%s): sources empty" % (where, title))
                    srcs = []
                for s in srcs:
                    if not isinstance(s, dict) or not (s.get("url") or "").strip():
                        err("%s (%s): source without url" % (where, title))
                note = o.get("alternateNoteAr")
                note = note.strip() if isinstance(note, str) else None
                cat = o.get("category")
                if cat not in CATEGORIES:
                    cat = "other"
                entries.append({
                    "month": mo, "day": day, "isNight": bool(o.get("isNight")),
                    "title": title, "category": cat,
                    "alt": variant == "alternate", "note": note or None,
                    "confidence": conf,
                    "urls": [s.get("url", "") for s in srcs if isinstance(s, dict)],
                })
    return entries


def is_int(v):
    return isinstance(v, int) and not isinstance(v, bool)


def load_scans():
    with open(SCANS, encoding="utf-8") as fh:
        data = json.load(fh)
    rows = {}
    for sc in data["scans"]:
        for r in sc["rows"]:
            rows[(sc["hijriMonth"], sc["hijriYear"], r["hijriDay"])] = r["note"]
    return rows


def check_scan_url(url, scans, where):
    """Validate a user-calendar:// reference; returns (month, day, note) or None."""
    m = SCAN_URL.match(url or "")
    if not m:
        err("%s: bad scan url %r" % (where, url))
        return None
    mo, yr, d = (int(x) for x in m.groups())
    note = scans.get((mo, yr, d))
    if note is None:
        err("%s: scan row not found: %s" % (where, url))
        return None
    return mo, d, note


def check_scan_source(src, scans, where):
    if not isinstance(src, dict) or src.get("name") != USER_CAL_NAME:
        err("%s: source must be {name: %r, url}" % (where, USER_CAL_NAME))
        return None
    return check_scan_url(src.get("url"), scans, where)


def load_convention(path, scans):
    try:
        with open(path, encoding="utf-8") as fh:
            c = json.load(fh)
    except Exception as e:  # noqa
        err("convention %s: cannot parse: %s" % (path, e))
        return None
    if not isinstance(c, dict):
        err("convention: top level must be an object")
        return None
    for k in ("swaps", "addSources", "scanOnly", "titleFixes", "noteFixes"):
        if not isinstance(c.get(k), list):
            err("convention: %r must be a list" % k)
            c[k] = []
    for k in ("exclusions", "userDecisions"):
        if k in c and not isinstance(c[k], list):
            err("convention: %r must be a list" % k)
            c[k] = []
        c.setdefault(k, [])

    def sel(o, where):
        if (not isinstance(o, dict) or not isinstance(o.get("month"), int)
                or not is_int(o.get("day")) or not (o.get("titleContains") or "").strip()):
            err("%s: needs month, day, titleContains" % where)
            return False
        return True

    for i, w in enumerate(c["swaps"]):
        where = "swaps[%d]" % i
        if not isinstance(w, dict) or not (w.get("event") or "").strip():
            err("%s: needs event" % where)
            continue
        sel(w.get("main"), where + ".main")
        sel(w.get("alternate"), where + ".alternate")
    for i, a in enumerate(c["addSources"]):
        where = "addSources[%d]" % i
        sel(a, where)
        check_scan_source(a.get("source") if isinstance(a, dict) else None, scans, where)
    for i, o in enumerate(c["scanOnly"]):
        where = "scanOnly[%d]" % i
        if not isinstance(o, dict):
            err("%s: not an object" % where)
            continue
        if not is_int(o.get("month")) or not 1 <= o["month"] <= 12:
            err("%s: bad month" % where)
        if not is_int(o.get("day")) or not 1 <= o["day"] <= 30:
            err("%s: bad day" % where)
        if not (o.get("titleAr") or "").strip():
            err("%s: empty titleAr" % where)
        if o.get("category") not in CATEGORIES:
            err("%s: bad category" % where)
        if o.get("variant") not in ("main", "alternate"):
            err("%s: bad variant" % where)
        if o.get("variant") == "alternate" and not (o.get("alternateNoteAr") or "").strip():
            err("%s: alternate needs alternateNoteAr" % where)
        if o.get("confidence") not in ("high", "medium"):
            err("%s: bad confidence" % where)
        if o.get("titleSource", "scan") not in ("scan", "db"):
            err("%s: bad titleSource" % where)
        srcs = o.get("sources")
        if not isinstance(srcs, list) or not srcs:
            err("%s: sources empty" % where)
            continue
        for sidx, src in enumerate(srcs):
            r = check_scan_source(src, scans, where)
            if not r:
                continue
            if (r[0], r[1]) != (o.get("month"), o.get("day")):
                err("%s: month/day differ from scan row %s" % (where, src.get("url")))
            if o.get("titleSource", "scan") == "scan" and (o.get("titleAr") or "").strip() not in r[2]:
                err("%s: titleAr is not verbatim in scan row %s" % (where, src.get("url")))
    for k in ("titleFixes", "noteFixes"):
        for i, f in enumerate(c[k]):
            if (not isinstance(f, dict) or not is_int(f.get("month")) or not is_int(f.get("day"))
                    or not (f.get("from") or "") or not isinstance(f.get("to"), str)):
                err("%s[%d]: needs month, day, from, to" % (k, i))
    return c


def find_one(entries, m, d, contains, where):
    hits = [e for e in entries if e["month"] == m and e["day"] == d and contains in e["title"]]
    if len(hits) != 1:
        err("%s: %d entries match month=%s day=%s titleContains=%r (need exactly 1)"
            % (where, len(hits), m, d, contains))
        return None
    return hits[0]


def label(e):
    return "%d/%d %s%s" % (e["month"], e["day"], e["title"],
                           " [%s]" % e["note"] if e["alt"] and e["note"] else "")


def apply_convention(entries, c):
    """Mutates [entries]; returns (swap log, scan-only log, extra duplicates)."""
    for f in c["titleFixes"]:
        hits = [e for e in entries if e["month"] == f["month"] and e["day"] == f["day"]
                and f["from"] in e["title"]]
        if len(hits) != 1:
            err("titleFix %s/%s: %r found in %d titles" % (f["month"], f["day"], f["from"], len(hits)))
            continue
        hits[0]["title"] = hits[0]["title"].replace(f["from"], f["to"])
    for f in c["noteFixes"]:
        hits = [e for e in entries if e["month"] == f["month"] and e["day"] == f["day"]
                and e["note"] and f["from"] in e["note"]]
        if len(hits) != 1:
            err("noteFix %s/%s: %r found in %d notes" % (f["month"], f["day"], f["from"], len(hits)))
            continue
        hits[0]["note"] = hits[0]["note"].replace(f["from"], f["to"])

    scan_log = []
    for o in c["scanOnly"]:
        if any(w in o["titleAr"] for w in DENYLIST):
            err("scanOnly %s/%s: title contains a denylisted word: %s" % (o["month"], o["day"], o["titleAr"]))
            continue
        entries.append({
            "month": o["month"], "day": o["day"], "isNight": bool(o.get("isNight")),
            "title": o["titleAr"].strip(), "category": o["category"],
            "alt": o["variant"] == "alternate",
            "note": (o.get("alternateNoteAr") or "").strip() or None,
            "confidence": o["confidence"],
            "urls": [x["url"] for x in o["sources"]],
        })
        scan_log.append(label(entries[-1]))

    swap_log = []
    for i, w in enumerate(c["swaps"]):
        where = "swaps[%d] (%s)" % (i, w.get("event"))
        mn = find_one(entries, w["main"]["month"], w["main"]["day"], w["main"]["titleContains"], where + ".main")
        al = find_one(entries, w["alternate"]["month"], w["alternate"]["day"],
                      w["alternate"]["titleContains"], where + ".alternate")
        if mn is None or al is None:
            continue
        if mn is al:
            err("%s: main and alternate are the same entry" % where)
            continue
        before = "main: %s | alt: %s" % (label(mn) if not mn["alt"] else "(alt) " + label(mn), label(al))
        mn["alt"] = False
        mn["note"] = None
        if (w.get("mainTitleAr") or "").strip():
            mn["title"] = w["mainTitleAr"].strip()
        keep = al["note"] if al["alt"] and al["note"] and al["note"].startswith(("على قول", "على رواية")) else None
        al["alt"] = True
        al["note"] = (w.get("alternateNoteAr") or "").strip() or keep or "على قول"
        swap_log.append((w["event"], before, "main: %s | alt: %s" % (label(mn), label(al))))

    for i, a in enumerate(c["addSources"]):
        e = find_one(entries, a["month"], a["day"], a["titleContains"], "addSources[%d]" % i)
        if e is not None and a["source"]["url"] not in e["urls"]:
            e["urls"].append(a["source"]["url"])
    return swap_log, scan_log


def merge_duplicates(entries):
    merged = {}
    order = []
    for e in entries:
        k = (e["month"], e["day"], e["title"], e["alt"])
        if k not in merged:
            merged[k] = e
            order.append(k)
            continue
        b = merged[k]
        for u in e["urls"]:
            if u not in b["urls"]:
                b["urls"].append(u)
        b["note"] = b["note"] or e["note"]
        if e["confidence"] == "high":
            b["confidence"] = "high"
    return [merged[k] for k in order], len(entries) - len(order)


def parse_args():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=None, help="directory for shia_occasions.dart and DATA-SUMMARY.md")
    ap.add_argument("--convention", default=CONVENTION)
    return ap.parse_args()


def main():
    args = parse_args()
    out_dart, out_md = OUT_DART, OUT_MD
    if args.out:
        os.makedirs(args.out, exist_ok=True)
        out_dart = os.path.join(args.out, "shia_occasions.dart")
        out_md = os.path.join(args.out, "DATA-SUMMARY.md")
    entries = load()
    scans = load_scans()
    conv = load_convention(args.convention, scans)
    if errors:
        sys.stderr.write("INVALID DATA:\n  " + "\n  ".join(errors) + "\n")
        sys.exit(1)

    dropped = []
    kept = []
    for e in entries:
        hit = [w for w in DENYLIST if w in e["title"]]
        if hit:
            dropped.append(e)
        else:
            kept.append(e)

    swap_log, scan_log = apply_convention(kept, conv)
    kept, dups = merge_duplicates(kept)
    for e in kept:
        if e["alt"] and not e["note"]:
            err("alternate without alternateNoteAr: %s" % label(e))
    if errors:
        sys.stderr.write("INVALID DATA:\n  " + "\n  ".join(errors) + "\n")
        sys.exit(1)

    # families / names / verified (R25)
    for e in kept:
        fams = []
        for u in e["urls"]:
            f = family(u)
            if f and f not in fams:
                fams.append(f)
        e["families"] = fams
        e["verified"] = len(fams) >= 2 and any(f not in WEAK_FAMILIES for f in fams)
        e["names"] = [FAMILY_NAMES.get(f, f) for f in fams]

    final = sorted(kept, key=lambda e: (e["month"], e["day"], e["alt"]))

    lines = [
        "// GENERATED by tool/gen_shia_occasions.py from docs/shia-occasions/research/*.json and convention.json — do not edit by hand.",
        "import '../domain/shia_occasion.dart';",
        "",
        "const List<ShiaOccasion> shiaOccasions = [",
    ]
    for e in final:
        parts = [
            "month: %d" % e["month"], "day: %d" % e["day"],
            "isNight: %s" % ("true" if e["isNight"] else "false"),
            "titleAr: %s" % dart_str(e["title"]),
            "category: OccasionCategory.%s" % e["category"],
            "isAlternate: %s" % ("true" if e["alt"] else "false"),
        ]
        if e["note"]:
            parts.append("alternateNoteAr: %s" % dart_str(e["note"]))
        parts += [
            "confidence: OccasionConfidence.%s" % e["confidence"],
            "verified: %s" % ("true" if e["verified"] else "false"),
            "sourceNames: [%s]" % ", ".join(dart_str(n) for n in e["names"]),
        ]
        lines.append("  ShiaOccasion(" + ", ".join(parts) + "),")
    lines += ["];", ""]
    with open(out_dart, "w", encoding="utf-8") as fh:
        fh.write("\n".join(lines))

    # summary
    rows = []
    tot = [0, 0, 0, 0]
    for m in range(1, 13):
        ms = [e for e in final if e["month"] == m]
        n, a = len(ms), sum(1 for e in ms if e["alt"])
        v = sum(1 for e in ms if e["verified"])
        r = [n, a, v, n - v]
        tot = [x + y for x, y in zip(tot, r)]
        rows.append((m, r))
    md = ["# Shia occasions data summary (generated)", "",
          "| Month | الشهر | Occasions | Alternates | Verified | Unverified |",
          "|---|---|---|---|---|---|"]
    for m, r in rows:
        md.append("| %d | %s | %d | %d | %d | %d |" % (m, MONTHS_AR[m - 1], *r))
    md.append("| | Total | %d | %d | %d | %d |" % tuple(tot))
    md += ["", "Verified = >= 2 distinct source families AND at least one family that is not the weak "
           "family alkafeel.net (R25). The user's calendar «%s» is its own strong family; "
           "shaaer.ir and saraer.org count as one family." % USER_CAL_NAME,
           "Duplicates merged: %d. Dropped by denylist: %d." % (dups, len(dropped))]
    for e in dropped:
        md.append("- dropped: month %d day %d %s" % (e["month"], e["day"], e["title"]))
    md += ["", "## Unverified entries (%d)" % tot[3], ""]
    for e in final:
        if not e["verified"]:
            md.append("- %d/%d%s %s (%s)" % (e["month"], e["day"], " (بديل)" if e["alt"] else "",
                                             e["title"], "، ".join(e["names"])))
    md += ["", "## Swaps applied (user's calendar defines the main date, R24)", ""]
    for ev, b, a in swap_log:
        md += ["- %s" % ev, "  - before: %s" % b, "  - after: %s" % a]
    md += ["", "## Scan-only additions (%d)" % len(scan_log), ""]
    md += ["- %s" % x for x in scan_log]
    md += ["", "## Exclusions (not added)", ""]
    for x in conv["exclusions"]:
        md.append("- %s/%s %s — %s" % (x.get("month") or "-", x.get("day") or "-", x.get("titleAr", ""), x.get("reason", "")))
    md += ["", "## Left for the user to decide", ""]
    for x in conv["userDecisions"]:
        md.append("- %s/%s %s — %s" % (x.get("month") or "-", x.get("day") or "-", x.get("titleAr", ""), x.get("reason", "")))
    text = "\n".join(md) + "\n"
    with open(out_md, "w", encoding="utf-8") as fh:
        fh.write(text)
    sys.stdout.write(text)


if __name__ == "__main__":
    main()
