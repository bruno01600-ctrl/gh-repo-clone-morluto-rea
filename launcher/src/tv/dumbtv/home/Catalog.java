package tv.dumbtv.home;

import android.content.Context;
import android.content.Intent;
import android.content.pm.ActivityInfo;
import android.content.pm.PackageManager;
import android.content.pm.ResolveInfo;
import android.media.tv.TvContract;
import android.media.tv.TvInputInfo;
import android.media.tv.TvInputManager;
import android.text.TextUtils;

import java.text.Collator;
import java.util.ArrayList;
import java.util.Collections;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/** Where tiles come from, and which of them the user wants on the home screen. */
final class Catalog {
    static final String APPS = "apps", INPUTS = "inputs";

    private Catalog() {}

    /** Every launchable app, TV apps first; drawables are left for {@link #art}. */
    static List<Item> apps(Context c) {
        PackageManager pm = c.getPackageManager();
        Map<String, Item> found = new LinkedHashMap<>();
        collect(pm, found, Intent.CATEGORY_LEANBACK_LAUNCHER, true, c.getPackageName());
        collect(pm, found, Intent.CATEGORY_LAUNCHER, false, c.getPackageName());
        List<Item> out = new ArrayList<>(found.values());
        Collator collator = Collator.getInstance();
        Collections.sort(out, (a, b) -> collator.compare(a.label.toString(), b.label.toString()));
        return out;
    }

    private static void collect(PackageManager pm, Map<String, Item> found, String category,
            boolean leanback, String self) {
        Intent query = new Intent(Intent.ACTION_MAIN).addCategory(category);
        for (ResolveInfo ri : pm.queryIntentActivities(query, 0)) {
            ActivityInfo ai = ri.activityInfo;
            if (ai.packageName.equals(self) || found.containsKey(ai.packageName)) continue;
            Intent launch = new Intent(Intent.ACTION_MAIN).addCategory(category)
                    .setClassName(ai.packageName, ai.name);
            Item it = new Item(ai.packageName, ri.loadLabel(pm), launch);
            it.info = ai;
            it.leanback = leanback;
            found.put(ai.packageName, it);
        }
    }

    /** Loads a banner, plus an icon for Afterglow or when there is no banner. Slow: off the UI thread. */
    static void art(PackageManager pm, Item it, boolean cornerIcon) {
        if (it.info == null) return;
        it.banner = it.info.loadBanner(pm);
        if (it.banner == null || cornerIcon) it.icon = it.info.loadIcon(pm);
    }

    /**
     * HDMI, AV and other passthrough inputs; HDMI first in port order. The intent is the TV's own
     * app for the input; {@link Input#intent} decides whether a tile opens that or the built-in
     * screen.
     */
    static List<Item> inputs(Context c, TvInputManager tv) {
        List<Item> out = new ArrayList<>();
        if (tv == null) return out;
        List<Item> other = new ArrayList<>();
        for (TvInputInfo in : tv.getTvInputList()) {
            if (!in.isPassthroughInput() || in.isHidden(c)) continue;
            CharSequence label = in.loadCustomLabel(c);
            if (TextUtils.isEmpty(label)) label = in.loadLabel(c);
            Intent view = new Intent(Intent.ACTION_VIEW,
                    TvContract.buildChannelUriForPassthroughInput(in.getId()));
            Item it = new Item(in.getId(), label, view);
            it.state = tv.getInputState(in.getId());
            (in.getType() == TvInputInfo.TYPE_HDMI ? out : other).add(it);
        }
        Collator collator = Collator.getInstance();
        Collections.sort(out, (a, b) -> collator.compare(a.label.toString(), b.label.toString()));
        Collections.sort(other, (a, b) -> collator.compare(a.label.toString(), b.label.toString()));
        out.addAll(other);
        return out;
    }

    static CharSequence label(Config cfg, Item it) {
        return cfg.get("name." + it.id, it.label.toString());
    }

    static boolean shown(Config cfg, String kind, Item it) {
        if (cfg.list(kind + ".hide").contains(it.id)) return false;
        return !APPS.equals(kind) || it.leanback || cfg.list("apps.show").contains(it.id);
    }

    static void setShown(Config cfg, String kind, Item it, boolean on) {
        List<String> hide = cfg.list(kind + ".hide");
        hide.remove(it.id);
        if (!on && (it.leanback || !APPS.equals(kind))) hide.add(it.id);
        cfg.setList(kind + ".hide", hide);
        if (APPS.equals(kind) && !it.leanback) {
            List<String> show = cfg.list("apps.show");
            show.remove(it.id);
            if (on) show.add(it.id);
            cfg.setList("apps.show", show);
        }
    }

    /** The shown items, in the user's order; anything never moved keeps catalog order. */
    static List<Item> visible(Config cfg, String kind, List<Item> all) {
        return visible(cfg, kind, all, null);
    }

    /** As above, then newest first by {@code recent} (package to last-used time) when it is set. */
    static List<Item> visible(Config cfg, String kind, List<Item> all, Map<String, Long> recent) {
        List<String> order = cfg.list(kind + ".order");
        List<Item> out = new ArrayList<>();
        for (Item it : all) {
            if (shown(cfg, kind, it)) out.add(it);
        }
        Collections.sort(out, (a, b) -> Integer.compare(rank(order, a.id), rank(order, b.id)));
        // The sort is stable, so apps with no record keep the user's order after the rest.
        if (recent != null) Collections.sort(out, (a, b) -> Recent.compare(recent, a.id, b.id));
        return out;
    }

    private static int rank(List<String> order, String id) {
        int i = order.indexOf(id);
        return i < 0 ? Integer.MAX_VALUE : i;
    }

    /** The user's categories, in row order. Each is a row of apps under the Apps row. */
    static List<String> categories(Config cfg) {
        return cfg.list("categories");
    }

    /** The category {@code it} is filed under, or null for the Apps row. */
    static String category(Config cfg, Item it) {
        String c = cfg.get("category." + it.id, "");
        return categories(cfg).contains(c) ? c : null;
    }

    /** Files {@code it} under {@code category}, or back in the Apps row when it is null. */
    static void setCategory(Config cfg, Item it, String category) {
        cfg.set("category." + it.id, category);
    }

    /** A name the comma-separated list can hold; empty when nothing usable is left. */
    static String categoryName(String raw) {
        return raw.replace(',', ' ').replaceAll("\\s+", " ").trim();
    }

    /** Adds a category at the end; false when the name is empty or already taken. */
    static boolean addCategory(Config cfg, String name) {
        List<String> all = categories(cfg);
        if (name.isEmpty() || all.contains(name)) return false;
        all.add(name);
        cfg.setList("categories", all);
        return true;
    }

    /** Renames a category and moves its apps along; false when the new name is unusable. */
    static boolean renameCategory(Config cfg, String from, String to) {
        List<String> all = categories(cfg);
        int i = all.indexOf(from);
        if (i < 0 || to.isEmpty() || all.contains(to)) return false;
        all.set(i, to);
        cfg.setList("categories", all);
        for (String key : cfg.keys("category.")) {
            if (from.equals(cfg.get(key, ""))) cfg.set(key, to);
        }
        return true;
    }

    /** Removes a category; its apps go back to the Apps row. */
    static void deleteCategory(Config cfg, String name) {
        List<String> all = categories(cfg);
        all.remove(name);
        cfg.setList("categories", all);
        for (String key : cfg.keys("category.")) {
            if (name.equals(cfg.get(key, ""))) cfg.set(key, null);
        }
    }

    /** Moves a category one row up (by -1) or down (by 1). */
    static void moveCategory(Config cfg, String name, int by) {
        List<String> all = categories(cfg);
        int from = all.indexOf(name), to = from + by;
        if (from < 0 || to < 0 || to >= all.size()) return;
        Collections.swap(all, from, to);
        cfg.setList("categories", all);
    }

    /** Saves {@code ids} as the new order, keeping the old positions of hidden items after them. */
    static void saveOrder(Config cfg, String kind, List<String> ids) {
        List<String> order = new ArrayList<>(ids);
        for (String id : cfg.list(kind + ".order")) {
            if (!order.contains(id)) order.add(id);
        }
        cfg.setList(kind + ".order", order);
    }
}
