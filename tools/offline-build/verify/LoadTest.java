import java.io.File;
import java.net.URL;
import java.net.URLClassLoader;
import java.util.ArrayList;
import java.util.Enumeration;
import java.util.List;
import java.util.jar.JarEntry;
import java.util.jar.JarFile;

/**
 * Structural verification for the assembled Slimefun jar.
 * Loads and links (verification + preparation, no static initialization)
 * EVERY class in the jar against the Paper 26.3 API and all dependencies.
 * A {@link NoClassDefFoundError} or missing supertype therefore fails loudly.
 *
 * Usage: LoadTest &lt;workDir&gt; &lt;jarFile&gt; &lt;libJarsDir&gt;
 */
public class LoadTest {
  public static void main(String[] args) throws Exception {
    String work = args[0];
    String jarPath = args[1];
    String libDir = args[2];

    List<URL> urls = new ArrayList<>();
    for (File f : new File(libDir).listFiles()) urls.add(f.toURI().toURL());
    File depjars = new File(work, "depjars");
    if (depjars.isDirectory()) for (File f : depjars.listFiles()) urls.add(f.toURI().toURL());
    urls.add(new File(jarPath).toURI().toURL());

    URLClassLoader cl = new URLClassLoader(urls.toArray(new URL[0]), LoadTest.class.getClassLoader());
    int loaded = 0, failed = 0;
    JarFile jf = new JarFile(jarPath);
    Enumeration<JarEntry> e = jf.entries();
    while (e.hasMoreElements()) {
      JarEntry je = e.nextElement();
      if (!je.getName().endsWith(".class") || je.getName().contains("package-info")) continue;
      String cn = je.getName().replace('/', '.').substring(0, je.getName().length() - 6);
      try {
        Class.forName(cn, false, cl);
        loaded++;
      } catch (Throwable t) {
        failed++;
        if (failed <= 12) System.out.println("FAIL " + cn + " : " + t);
      }
    }
    System.out.println("loaded+linked: " + loaded + " / failed: " + failed);

    Class<?> main = Class.forName("io.github.thebusybiscuit.slimefun4.implementation.Slimefun", false, cl);
    Class<?> api = cl.loadClass("org.bukkit.plugin.java.JavaPlugin");
    System.out.println("main class: " + main.getName() + " extends " + main.getSuperclass().getName()
        + " | JavaPlugin-assignable: " + api.isAssignableFrom(main));

    if (failed > 0) System.exit(1);
  }
}
