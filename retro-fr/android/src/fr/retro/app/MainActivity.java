package fr.retro.app;

import android.app.Activity;
import android.content.ActivityNotFoundException;
import android.content.ClipData;
import android.content.Intent;
import android.net.Uri;
import android.os.Bundle;
import android.view.View;
import android.view.Window;
import android.view.WindowManager;
import android.webkit.ValueCallback;
import android.webkit.WebChromeClient;
import android.webkit.WebResourceRequest;
import android.webkit.WebResourceResponse;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;

import java.io.IOException;
import java.io.InputStream;
import java.util.HashMap;
import java.util.Locale;
import java.util.Map;

/**
 * Une WebView plein écran qui affiche l'application web embarquée dans assets/web.
 * Les fichiers sont servis sous https://appassets.androidplatform.net/ pour que
 * IndexedDB, les fetch et WebAssembly fonctionnent comme sur un vrai site.
 */
public class MainActivity extends Activity {
    private static final String HOTE = "appassets.androidplatform.net";
    private static final String ACCUEIL = "https://" + HOTE + "/index.html";
    private static final int CHOIX_FICHIERS = 1;

    private WebView web;
    private ValueCallback<Uri[]> attenteFichiers;

    @Override
    protected void onCreate(Bundle etat) {
        super.onCreate(etat);
        requestWindowFeature(Window.FEATURE_NO_TITLE);
        getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);

        web = new WebView(this);
        setContentView(web);

        WebSettings s = web.getSettings();
        s.setJavaScriptEnabled(true);
        s.setDomStorageEnabled(true);
        s.setDatabaseEnabled(true);
        s.setMediaPlaybackRequiresUserGesture(false);
        s.setAllowFileAccess(false);
        s.setAllowContentAccess(true);
        s.setSupportMultipleWindows(false);
        s.setCacheMode(WebSettings.LOAD_DEFAULT);

        web.setWebViewClient(new Client());
        web.setWebChromeClient(new Chrome());

        if (etat != null) {
            web.restoreState(etat);
        } else {
            web.loadUrl(ACCUEIL);
        }
    }

    @Override
    protected void onSaveInstanceState(Bundle etat) {
        super.onSaveInstanceState(etat);
        web.saveState(etat);
    }

    @Override
    public void onWindowFocusChanged(boolean focus) {
        super.onWindowFocusChanged(focus);
        if (focus) pleinEcran();
    }

    @SuppressWarnings("deprecation")
    private void pleinEcran() {
        getWindow().getDecorView().setSystemUiVisibility(
                View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
                        | View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                        | View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
                        | View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                        | View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                        | View.SYSTEM_UI_FLAG_FULLSCREEN);
    }

    @Override
    @SuppressWarnings("deprecation")
    public void onBackPressed() {
        String url = web.getUrl();
        if (url != null && url.contains("/play.html")) {
            web.loadUrl(ACCUEIL);
        } else if (web.canGoBack()) {
            web.goBack();
        } else {
            super.onBackPressed();
        }
    }

    @Override
    protected void onPause() {
        web.onPause();
        super.onPause();
    }

    @Override
    protected void onResume() {
        super.onResume();
        web.onResume();
    }

    @Override
    protected void onActivityResult(int requete, int resultat, Intent donnees) {
        if (requete != CHOIX_FICHIERS || attenteFichiers == null) {
            super.onActivityResult(requete, resultat, donnees);
            return;
        }
        Uri[] uris = null;
        if (resultat == RESULT_OK && donnees != null) {
            ClipData clip = donnees.getClipData();
            if (clip != null) {
                uris = new Uri[clip.getItemCount()];
                for (int i = 0; i < uris.length; i++) uris[i] = clip.getItemAt(i).getUri();
            } else if (donnees.getData() != null) {
                uris = new Uri[] {donnees.getData()};
            }
        }
        attenteFichiers.onReceiveValue(uris);
        attenteFichiers = null;
    }

    private class Chrome extends WebChromeClient {
        @Override
        public boolean onShowFileChooser(WebView vue, ValueCallback<Uri[]> rappel, FileChooserParams params) {
            if (attenteFichiers != null) attenteFichiers.onReceiveValue(null);
            attenteFichiers = rappel;
            // Les fichiers de jeu n'ont pas de type MIME connu : on accepte tout.
            Intent i = new Intent(Intent.ACTION_OPEN_DOCUMENT);
            i.addCategory(Intent.CATEGORY_OPENABLE);
            i.setType("*/*");
            i.putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true);
            try {
                startActivityForResult(i, CHOIX_FICHIERS);
            } catch (ActivityNotFoundException e) {
                attenteFichiers = null;
                return false;
            }
            return true;
        }
    }

    private class Client extends WebViewClient {
        @Override
        public boolean shouldOverrideUrlLoading(WebView vue, WebResourceRequest req) {
            Uri u = req.getUrl();
            if (HOTE.equals(u.getHost())) return false;
            // Les liens externes (pages des jeux gratuits) s'ouvrent dans le navigateur.
            try {
                startActivity(new Intent(Intent.ACTION_VIEW, u));
            } catch (ActivityNotFoundException ignore) {
                // aucun navigateur : on reste dans l'application
            }
            return true;
        }

        @Override
        public WebResourceResponse shouldInterceptRequest(WebView vue, WebResourceRequest req) {
            Uri u = req.getUrl();
            if (!HOTE.equals(u.getHost())) return null;
            String chemin = u.getPath();
            if (chemin == null || chemin.equals("/")) chemin = "/index.html";
            if (chemin.contains("..")) return introuvable();
            try {
                InputStream in = getAssets().open("web" + chemin);
                WebResourceResponse r = new WebResourceResponse(typeMime(chemin), null, in);
                Map<String, String> entetes = new HashMap<String, String>();
                entetes.put("Access-Control-Allow-Origin", "*");
                entetes.put("Cache-Control", "no-cache");
                r.setResponseHeaders(entetes);
                return r;
            } catch (IOException e) {
                return introuvable();
            }
        }

        private WebResourceResponse introuvable() {
            WebResourceResponse r = new WebResourceResponse("text/plain", "utf-8", null);
            r.setStatusCodeAndReasonPhrase(404, "Not Found");
            return r;
        }
    }

    static String typeMime(String chemin) {
        String c = chemin.toLowerCase(Locale.ROOT);
        if (c.endsWith(".html")) return "text/html";
        if (c.endsWith(".js")) return "text/javascript";
        if (c.endsWith(".css")) return "text/css";
        if (c.endsWith(".json")) return "application/json";
        if (c.endsWith(".wasm")) return "application/wasm";
        if (c.endsWith(".svg")) return "image/svg+xml";
        if (c.endsWith(".png")) return "image/png";
        return "application/octet-stream";
    }
}
