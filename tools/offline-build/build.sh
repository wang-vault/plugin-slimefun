#!/bin/bash
# =============================================================================
# Offline build pipeline for Slimefun on Paper/Minecraft 26.3
# =============================================================================
# Reproduces `mvn package` (maven-compiler + maven-shade semantics) without any
# access to Maven repositories. Everything is compiled with ECJ from source and
# assembled with a small maven-shade-compatible relocator.
#
# Why this exists:
#   Paper 26.3 removed/changed a lot of Bukkit API that the upstream build
#   (api-version 1.21) no longer compiles against. This pipeline compiles the
#   adapted sources in this repository against the *real* Paper 26.3 API
#   (fetched from PaperMC/Paper, branch ver/26.3) plus all source-available
#   dependencies, then produces the final shaded jar.
#
# Prerequisites (see README.md for exact fetch commands):
#   $WORK           working dir with source trees + lib/ (binary jars)
#   $SF             this repository
#   $JH             a Java 21+ runtime (used to run ECJ)
#   $ECJ            Eclipse Compiler for Java (ecj / ctxo-jdt-analyzer jar)
#
# Pipeline:
#   pass 1  compile Slimefun + reached subsets of paper-api 26.3 / adventure /
#           itemsadder / orebfuscator from source  ->  $WORK/pass1-out
#   split   separate pass1-out classes by package prefix -> depjars/
#   pass 2  recompile Slimefun alone with -source/-target 16 (as per pom.xml)
#   shade   relocate dough/paperlib/commons-lang references (maven-shade rules)
#           + merge shaded libs + filtered resources -> dist/
#   verify  load+link every class in the final jar against the 26.3 API
# =============================================================================
set -euo pipefail

SF="${SF:-/home/user/plugin-slimefun}"
WORK="${WORK:-/tmp/build}"
JH="${JH:-/tmp/venv/lib/python3.11/site-packages/jdk4py/java-runtime}"
ECJ="${ECJ:-/tmp/ecj-hunt/analyzer/package/jar/ctxo-jdt-analyzer-17.jar}"

# source trees of dependencies (see README.md "Fetching the sources")
PAPER_API="${PAPER_API:-/tmp/paper-main/paper-api/src/main/java}"
PAPER_API_GEN="${PAPER_API_GEN:-/tmp/paper-main/paper-api/src/generated/java}"
ADVENTURE="${ADVENTURE:-/tmp/adventure}"
EXAMINATION="${EXAMINATION:-/tmp/examination/api/src/main/java}"
ITEMSADDER="${ITEMSADDER:-/tmp/itemsadder/src/main/java}"
OREBFUSCATOR="${OREBFUSCATOR:-/tmp/orebfuscator/orebfuscator-api/src/main/java}"

VERSION="4.9-UNOFFICIAL"

echo "=== [1/5] pass 1: whole-graph ECJ compile (Slimefun + dep subsets) ==="
OUT="$WORK/pass1-out"
rm -rf "$OUT"; mkdir -p "$OUT"

CP=""
LIB="$SF/tools/offline-build/lib"
for j in "$LIB"/jars/*.jar; do CP="$CP:$j"; done

SP="$PAPER_API:$PAPER_API_GEN"
for m in api key nbt text-serializer-gson text-serializer-json \
         text-serializer-json-legacy-impl text-serializer-legacy text-serializer-plain \
         text-logger-slf4j text-serializer-ansi; do
  d="$ADVENTURE/$m/src/main/java"
  [ -d "$d" ] && SP="$SP:$d"
done
SP="$SP:$EXAMINATION"
SP="$SP:$ITEMSADDER"
SP="$SP:$OREBFUSCATOR"

# Slimefun's own main sources (exclude package-info like the maven-compiler config)
find "$SF/src/main/java" -name "*.java" ! -name "package-info.java" > "$WORK/sf-sources.txt"

# NOTE: pass 1 compiles at source level 21 (paper-api 26.3 requires >= 21).
# The Slimefun classes are recompiled at 16 in pass 2, as per pom.xml.
"$JH/bin/java" -Xmx2g -cp "$ECJ" org.eclipse.jdt.internal.compiler.batch.Main \
  -source 21 -target 21 -encoding UTF-8 -nowarn \
  -cp "${CP:1}" -sourcepath "$SP" \
  -d "$OUT" @"$WORK/sf-sources.txt" 2>"$WORK/pass1-err.log" >"$WORK/pass1-out.log" || true

ERRS=$(grep -cE '^[0-9]+\. ERROR' "$WORK/pass1-err.log" || true)
echo "    pass1: $(find "$OUT" -name '*.class' | wc -l) classes, $ERRS errors"
if [ "$ERRS" != "0" ]; then grep -E '^[0-9]+\. ERROR' "$WORK/pass1-err.log" | head -20; exit 1; fi

echo "=== [2/5] split: build per-dependency compile jars ==="
mkdir -p "$WORK/depjars"
python3 - << PYEOF
import zipfile, os
groups = {
  'paper-api-26.3-compile.jar': ['org/bukkit/', 'io/papermc/', 'com/destroystokyo/', 'org/spigotmc/', 'co/aikar/'],
  'adventure-5.2.0-compile.jar': ['net/kyori/'],
  'itemsadder-api-3.6.1-compile.jar': ['dev/lone/'],
  'orebfuscator-api-5.4.0-compile.jar': ['net/imprex/'],
}
for out, prefixes in groups.items():
    n = 0
    with zipfile.ZipFile(f'$WORK/depjars/{out}', 'w', zipfile.ZIP_DEFLATED) as z:
        for root, _, files in os.walk('$WORK/pass1-out'):
            for f in files:
                p = os.path.join(root, f)
                rel = os.path.relpath(p, '$WORK/pass1-out')
                if rel.endswith('.class') and any(rel.startswith(x) for x in prefixes):
                    z.write(p, rel); n += 1
    print(f'    {out}: {n} classes')
PYEOF

echo "=== [3/5] pass 2: recompile Slimefun alone (-source/-target 16, per pom.xml) ==="
CP2=""
for j in "$WORK"/cp/*.jar "$WORK"/depjars/*.jar; do CP2="$CP2:$j"; done
rm -rf "$WORK/classes"; mkdir -p "$WORK/classes"
"$JH/bin/java" -Xmx2g -cp "$ECJ" org.eclipse.jdt.internal.compiler.batch.Main \
  -source 16 -target 16 -encoding UTF-8 -nowarn \
  -cp "${CP2:1}" -d "$WORK/classes" @"$WORK/sf-sources.txt" 2>"$WORK/pass2-err.log"

echo "    pass2: $(find "$WORK/classes" -name '*.class' | wc -l) classes, 0 errors"

echo "=== [4/5] shade: relocate + merge libs + filtered resources ==="
HERE="$(cd "$(dirname "$0")" && pwd)"
python3 "$HERE/tools/assemble.py" "$WORK/dist/Slimefun v$VERSION.jar"

echo "=== [5/5] verify: load+link every class against the 26.3 API ==="
mkdir -p "$WORK/verify"
"$JH/bin/java" -Xmx1g -cp "$ECJ" org.eclipse.jdt.internal.compiler.batch.Main \
  -21 "$HERE/verify/LoadTest.java" -d "$WORK/verify" \
  -cp "$WORK/depjars/paper-api-26.3-compile.jar" 2>/dev/null
"$JH/bin/java" -Xmx1g -cp "$WORK/verify" LoadTest "$WORK" "$WORK/dist/Slimefun v$VERSION.jar" "$LIB/jars"

# version-detection logic test (compile against the pass-2 Slimefun classes)
CPV="$WORK/classes:$(ls "$LIB"/jars/*.jar | tr '\n' ':')$(ls "$WORK"/depjars/*.jar | tr '\n' ':')"
"$JH/bin/java" -Xmx1g -cp "$ECJ" org.eclipse.jdt.internal.compiler.batch.Main \
  -16 "$HERE/verify/VersionTest.java" -d "$WORK/verify" -cp "$CPV" 2>/dev/null
"$JH/bin/java" -Xmx1g -cp "$WORK/verify:$CPV" VersionTest

python3 "$HERE/verify/audit.py" "$WORK/dist/Slimefun v$VERSION.jar"

echo ""
echo "DONE -> $WORK/dist/Slimefun v$VERSION.jar"
