package io.github.thebusybiscuit.slimefun4.utils;

import java.util.regex.Pattern;

import org.bukkit.ChatColor;

/**
 * This class is created for common-use patterns used in things such as {@link String#split(String)}. <br>
 * Every time something like {@link String#split(String)} is called it will compile a {@link Pattern},
 * for code that is called often this can be a massive performance loss.
 * This class solves that, one compile but many uses!
 * 
 * @author Walshy
 * @author TheBusyBiscuit
 * 
 */
public final class PatternUtils {

    private PatternUtils() {}

    public static final Pattern SLASH_SEPARATOR = Pattern.compile(" / ");

    public static final Pattern YAML_ENTRY = Pattern.compile("[a-z0-9_-]+:.*");

    public static final Pattern MINECRAFT_NAMESPACEDKEY = Pattern.compile("minecraft:[a-z0-9/._-]+");

    public static final Pattern MINECRAFT_TAG = Pattern.compile("#minecraft:[a-z_]+");
    public static final Pattern SLIMEFUN_TAG = Pattern.compile("#slimefun:[a-z_]+");

    /**
     * This pattern matches the year-based Minecraft versioning scheme which was
     * introduced in 2026 (e.g. "26.3" for "Wilderness Bound").
     * The major component of this format is always at least two digits long,
     * so it can never collide with the old "1.x" format whose major component
     * is always a single "1".
     * It is checked against {@link org.bukkit.Bukkit#getVersion()} which contains
     * a suffix like "(MC: 26.3)".
     */
    public static final Pattern MINECRAFT_YEAR_BASED_VERSION = Pattern.compile("\\(MC: (\\d{2,})\\.(\\d+)");

    public static final Pattern USES_LEFT_LORE = Pattern.compile(ChatColor.YELLOW + "[0-9]+ Uses? " + ChatColor.GRAY + "left");

}
