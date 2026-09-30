# Binary classpath jars (not committed)

These jars form the compile-time classpath (`$WORK/cp/`). They are NOT stored
in git — re-fetch them as described below. Sizes shown for verification.

| jar | size | source |
| --- | ---- | ------ |
| fastutil-8.5.15.jar | 23.7 MB | Paper runtime library — vendored in a public server pack: `api.github.com/repos/GAME-CLI-SRV-DEV/APX-Server/contents/...` (raw download, `Accept: application/vnd.github.raw`) |
| WorldEdit.jar | 6.4 MB | same server pack (WorldEdit 7.x, `com.sk89q.worldedit` API) |
| guava-33.3.1-jre.jar | 3.1 MB | same server pack |
| adventure-text-minimessage-4.26.1.jar | — | vendored in `shafiafg/Custom_plugin` (`libs/`); also the source of the minimessage-classes-only jar |
| authlib-6.0.57.jar, brigadier-1.3.10.jar, bungeecord-chat-*.jar, gson-2.11.0.jar, snakeyaml-2.2.jar, log4j-api-2.24.1.jar, joml-1.10.8.jar, jsr305-*.jar, commons-lang-2.6.jar, PlaceholderAPI-2.11.6.jar, adventure/examination jars, ... | — | Paper/Slimefun runtime libraries from the same public server pack |
| commons-lang3-3.17.0.jar | 0.7 MB | `libraries/org/apache/commons/commons-lang3/3.17.0/` in the same server pack (needed by paper-api 26.3 `Player`/`Instrument`) |
| maven-resolver-{api,spi,impl,connector-basic,transport-http}-1.9.22.jar | ~1.5 MB total | `apache-maven-3.9.9/lib/` vendored in `shafiafg/Custom_plugin` (needed by paper-api `LibraryLoader`) |
| mcmmo-2.2.029-standin.jar | 1.3 MB | built locally from mcMMO @ `6a9962a2` (see main README) |
| minimessage-4.26.1-classes.jar | small | extracted `net/kyori/adventure/text/minimessage/**` from adventure-text-minimessage-4.26.1.jar |

The `depjars/` (paper-api-26.3-compile.jar etc.) are *produced* by the build
pipeline (step 2) — they are the reached subsets compiled from the source
trees listed in the main README.

Also required (tooling, not classpath):
- **ECJ**: `ctxo-jdt-analyzer-17.jar` — Eclipse Compiler 3.39.0 transported in
  the npm package `@ctxo/lang-java-analyzer` 0.9.0
  (`registry.npmjs.org/@ctxo/lang-java-analyzer/-/lang-java-analyzer-0.9.0.tgz`,
  jar inside `package/jar/`).
- **Java runtime**: any JDK/JRE 21+ (used to run ECJ); the port was built with
  the jdk4py Java 25 runtime.

## The reference jar

`Slimefun-v4.9-UNOFFICIAL.jar` (the official-style 4.9 build obtained from the
same public server pack) is used for exactly one purpose: the already-relocated
shaded library classes (`io.github.thebusybiscuit.slimefun4.libraries.{dough,
paperlib,commons}`) that are merged into the final jar. These correspond to the
versions pinned in `pom.xml` (dough @ `cb22e71335`, paperlib 1.0.8,
commons-lang 2.6). The class sets were compared and verified to match the
pinned dough sources.
