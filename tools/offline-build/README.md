# Offline build pipeline — Slimefun for Paper / Minecraft 26.3

This directory contains everything needed to build the adapted Slimefun sources
in this repository into a working plugin jar **without any access to Maven
repositories** (the sandbox this port was developed in cannot reach
`repo.papermc.io`, `jitpack.io` or Maven Central).

It reproduces the semantics of the official `mvn package`:

| official Maven step                                | reproduced here                                        |
| -------------------------------------------------- | ------------------------------------------------------ |
| `maven-compiler-plugin` (source/target 16, package-info excluded) | pass 2 (ECJ `-source 16 -target 16`)      |
| `maven-compiler-plugin` for *all* dependency artifacts actually only resolves binaries | pass 1 compiles the *reached* subset of Paper 26.3 API + adventure from source |
| `maven-shade-plugin` relocations (dough, paperlib, commons-lang) | `tools/relocate.py` (constant-pool rewriter)   |
| shade'd libraries (dough, paperlib, commons-lang 2.6) | merged from the official 4.9 build's shaded classes (same pinned versions) |
| `<resources>` filtering (`${project.version}`)     | `tools/assemble.py`                                     |
| jar manifest + maven metadata                      | `tools/assemble.py`                                     |

## Layout

```
tools/offline-build/
  build.sh          one-shot pipeline (5 steps, see below)
  tools/assemble.py jar assembly: relocation + shading + resources
  tools/relocate.py constant-pool class relocator (mini maven-shade)
  verify/LoadTest.java  loads+links every class of the final jar vs 26.3 API
  verify/VersionTest.java  runtime test of the year-based version detection
  verify/audit.py   asserts no un-relocated references remain in the jar
  lib/              binary classpath jars (NOT committed — see lib/README.md)
```

## The 5 steps

1. **pass 1 — whole-graph compile.** ECJ compiles all Slimefun main sources
   (665 files) with the *source-available* dependencies on the sourcepath:
   Paper **26.3** API (`PaperMC/Paper`, branch `ver/26.3`), adventure 5.2.0
   (+examination), ItemsAdder API, Orebfuscator API. ECJ only pulls in the
   subset of each project that Slimefun actually reaches — that subset is the
   exact "paper-api 26.3" the plugin compiles against.
   Compiled at `-source 21 -target 21` (Paper 26.3 API sources require >= 21).
2. **split.** The pass-1 output is separated by package prefix into per-project
   compile jars (`depjars/`).
3. **pass 2.** Slimefun's own sources are recompiled **alone** at
   `-source 16 -target 16` (exactly what `pom.xml` configures) against the
   binary classpath — producing the classes that end up in the plugin jar.
4. **shade.** `assemble.py` relocates the three shaded-library prefixes with
   the same rules as `maven-shade-plugin` in `pom.xml`:
   - `io.github.bakedlibs.dough`    → `io.github.thebusybiscuit.slimefun4.libraries.dough`
   - `io.papermc.lib`               → `io.github.thebusybiscuit.slimefun4.libraries.paperlib`
   - `org.apache.commons.lang`      → `io.github.thebusybiscuit.slimefun4.libraries.commons.lang`

   then merges the shaded library classes, the filtered resources
   (`plugin.yml` with `${project.version}` → `4.9-UNOFFICIAL`, `api-version:
   '26.3'`), a minimal manifest and the Maven metadata.
5. **verify.**
   - `LoadTest` loads and *links* every class of the final jar against the
     Paper 26.3 API + all dependencies (any missing supertype / changed
     signature fails loudly).
   - `VersionTest` checks the year-based Minecraft version detection
     (26.3 → `MinecraftVersion.MINECRAFT_26_3`, legacy 1.x strings unaffected).
   - `audit.py` asserts no un-relocated references remain.

Last full run: **942/942 classes linked, 0 failures; all version tests passed;
0 unrelocated references.**

## Running

```bash
# prerequisites (defaults shown, override via env):
#   SF=/home/user/plugin-slimefun   WORK=/tmp/build
#   JH=<java 21+ runtime>  ECJ=<ECJ jar>  + source trees & lib/ as below
bash tools/offline-build/build.sh
# -> $WORK/dist/Slimefun v4.9-UNOFFICIAL.jar
```

## Fetching the sources (reproducibility)

All dependencies are fetched from public GitHub repositories:

| tree      | command |
| --------- | ------- |
| Paper 26.3 API | `curl -sL https://codeload.github.com/PaperMC/Paper/tar.gz/refs/heads/ver/26.3` → extract, use `paper-api/src/{main,generated}/java` |
| adventure 5.2.0 | `https://codeload.github.com/KyoriPowered/adventure/tar.gz/refs/heads/master` (modules: api, key, nbt, text-serializer-*) |
| examination | `https://codeload.github.com/KyoriPowered/examination/tar.gz/refs/heads/master` |
| ItemsAdder API | `https://codeload.github.com/LoneDev6/ItemsAdder/tar.gz/refs/heads/master` (`src/main/java`, `dev.lone.api` package) |
| Orebfuscator API | `https://codeload.github.com/Imprex-Development/Orebfuscator/tar.gz/refs/heads/master` (`orebfuscator-api`) |
| mcMMO 2.2.029 (compile-time stand-in, see below) | `git clone https://github.com/mcMMO-Dev/mcMMO.git` @ `6a9962a2dc13b56eda7f4740f20752745fa9594b` |

Binary classpath jars (`lib/`) provenance is documented in `lib/README.md`.

## Why some dependencies are special

- **Paper 26.3 API from source**: no prebuilt `paper-api-26.3` jar is
  reachable from the sandbox; compiling the *reached subset* from the official
  sources is the most faithful substitute possible (it is literally the API
  the server implements).
- **mcMMO stand-in**: Slimefun has an optional mcMMO integration compiled
  against mcMMO 2.2.029 (pinned in `pom.xml`). No binary artifact is available
  anywhere public, so the exact pinned release commit is compiled with
  `-proceedOnError` (its own unrelated deps are allowed to fail) and only the
  `com.gmail.nossr50` classes Slimefun touches are kept, after verifying the
  required method signatures by constant-pool inspection
  (`mcMMO.getPlaceStore()`, `SkillUtils.removeAbilityBuff(ItemStack)`,
  `McMMOPlayerSalvageCheckEvent` members).
- **MiniMessage classes-only jar**: the Paper 26.3 API itself references
  `net.kyori.adventure.text.minimessage` (e.g. `CommandSender#sendRichMessage`).
  The MiniMessage API surface used there is identical between 4.26.1 and
  5.2.0, so the minimessage-only classes are extracted from the official
  `adventure-text-minimessage-4.26.1` jar (excluding adventure-api classes to
  avoid shadowing the 5.2.0 source-compiled ones).
- **maven-resolver jars**: `paper-api`'s `LibraryLoader` (runtime library
  downloading) references `org.eclipse.aether.*`; the five
  `maven-resolver-*-1.9.22.jar` files come from the Apache Maven 3.9.9
  distribution.
- **Shaded libraries (dough, paperlib, commons-lang)**: taken from the
  official-style 4.9 build's already-relocated classes (identical pinned
  versions: dough @ `cb22e71335`, paperlib 1.0.8, commons-lang 2.6). Their
  linkage against the 26.3 API is verified by `LoadTest`. PaperLib's own
  version detection cannot parse the year-based scheme and therefore falls
  back to its *synchronous* handlers (see README at repository root,
  "Known limitations").
