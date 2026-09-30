import io.github.thebusybiscuit.slimefun4.api.MinecraftVersion;
import io.github.thebusybiscuit.slimefun4.utils.PatternUtils;
import java.util.regex.Matcher;

/**
 * Runtime logic test for the year-based (2026+) Minecraft version detection
 * that was added for Paper 26.3 support (see Slimefun#isVersionUnsupported).
 *
 * Usage: VersionTest &lt;slimefunClassesDir&gt; (compile against pass-2 output)
 */
public class VersionTest {
  static int[] detect(String bukkitVersion) {
    int version = 0, patch = 0; // PaperLib returns 0 for the year-based scheme (single-digit-major regex)
    if (version <= 0) {
      Matcher m = PatternUtils.MINECRAFT_YEAR_BASED_VERSION.matcher(bukkitVersion);
      if (m.find()) { version = Integer.parseInt(m.group(1)); patch = Integer.parseInt(m.group(2)); }
    }
    return new int[]{version, patch};
  }
  static MinecraftVersion match(int version, int patch) {
    for (MinecraftVersion v : MinecraftVersion.values())
      if (v.isMinecraftVersion(version, patch)) return v;
    return null;
  }
  public static void main(String[] a) {
    int fails = 0;
    fails += check(detect("git-Paper-41 (MC: 26.3)"), 26, 3, MinecraftVersion.MINECRAFT_26_3);
    fails += check(detect("git-Paper-140 (MC: 26.3)"), 26, 3, MinecraftVersion.MINECRAFT_26_3);
    // legacy format must NOT be matched by the new pattern (PaperLib's own path)
    fails += check(detect("git-Paper-124 (MC: 1.21.4)"), 0, 0, null);
    // unknown/unparseable -> benign "assume supported" (0.0)
    fails += check(detect("Some custom fork"), 0, 0, null);
    // a future 26.4 is treated as >= 26.3 (mirrors upstream 1.21.x handling)
    fails += check(detect("git-Paper-99 (MC: 26.4)"), 26, 4, MinecraftVersion.MINECRAFT_26_3);
    // version gates: 26.3 must take all "modern" paths
    MinecraftVersion v = MinecraftVersion.MINECRAFT_26_3;
    if (!v.isAtLeast(MinecraftVersion.MINECRAFT_1_21)) { System.out.println("FAIL isAtLeast(1.21)"); fails++; }
    if (v.isBefore(MinecraftVersion.MINECRAFT_1_21)) { System.out.println("FAIL isBefore(1.21)"); fails++; }
    if (!v.isAtLeast(MinecraftVersion.MINECRAFT_1_20_5)) { System.out.println("FAIL isAtLeast(1.20.5)"); fails++; }
    if (v.isBefore(MinecraftVersion.MINECRAFT_1_19)) { System.out.println("FAIL isBefore(1.19)"); fails++; }
    // legacy regression: 1.20.1 still matches MINECRAFT_1_20 via PaperLib-provided ints
    if (!MinecraftVersion.MINECRAFT_1_20.isMinecraftVersion(20, 1)) { System.out.println("FAIL 1.20.1 legacy match"); fails++; }
    System.out.println(fails == 0 ? "ALL VERSION TESTS PASSED" : fails + " TESTS FAILED");
    if (fails > 0) System.exit(1);
  }
  static int check(int[] d, int ev, int ep, MinecraftVersion expect) {
    MinecraftVersion m = match(d[0], d[1]);
    boolean ok = d[0] == ev && d[1] == ep && (m == expect || (expect == null && m == null));
    System.out.println((ok ? "ok  " : "FAIL") + " detect -> " + d[0] + "." + d[1] + " match=" + m);
    return ok ? 0 : 1;
  }
}
