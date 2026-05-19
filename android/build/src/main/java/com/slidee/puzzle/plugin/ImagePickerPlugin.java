package com.slidee.puzzle.plugin;

import android.app.Activity;
import android.content.Intent;
import android.net.Uri;
import android.provider.MediaStore;

import androidx.annotation.NonNull;
import androidx.collection.ArraySet;

import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.SignalInfo;
import org.godotengine.godot.plugin.UsedByGodot;

import java.util.Set;

/**
 * Godot Android plugin that opens the system photo picker and returns the
 * selected image path to GDScript via the "image_picked" signal.
 *
 * Registration name: "GodotImagePicker"
 *
 * GDScript usage:
 *   var picker = Engine.get_singleton("GodotImagePicker")
 *   picker.connect("image_picked", self, "_on_image_picked")
 *   picker.connect("cancelled",    self, "_on_cancelled")
 *   picker.pick_image()
 */
public class ImagePickerPlugin extends GodotPlugin {

    private static final int REQUEST_PICK_IMAGE = 1001;

    public ImagePickerPlugin(Godot godot) {
        super(godot);
    }

    @NonNull
    @Override
    public String getPluginName() {
        return "GodotImagePicker";
    }

    @NonNull
    @Override
    public Set<SignalInfo> getPluginSignals() {
        Set<SignalInfo> signals = new ArraySet<>();
        // Emitted with the absolute file path of the chosen image
        signals.add(new SignalInfo("image_picked", String.class));
        // Emitted when user cancels without choosing
        signals.add(new SignalInfo("cancelled"));
        return signals;
    }

    /** Called from GDScript to open the system image picker. */
    @UsedByGodot
    public void pick_image() {
        Activity activity = getActivity();
        if (activity == null) return;

        Intent intent = new Intent(Intent.ACTION_PICK,
                MediaStore.Images.Media.EXTERNAL_CONTENT_URI);
        intent.setType("image/*");
        activity.startActivityForResult(intent, REQUEST_PICK_IMAGE);
    }

    @Override
    public void onMainActivityResult(int requestCode, int resultCode, Intent data) {
        if (requestCode != REQUEST_PICK_IMAGE) return;

        Activity activity = getActivity();
        if (activity == null) return;

        if (resultCode == Activity.RESULT_OK && data != null) {
            Uri uri = data.getData();
            if (uri != null) {
                // Resolve the URI to a real file path the Godot engine can open
                String path = resolveRealPath(activity, uri);
                if (path != null) {
                    emitSignal("image_picked", path);
                    return;
                }
            }
        }
        emitSignal("cancelled");
    }

    /** Resolves a content:// URI to an absolute filesystem path. */
    private String resolveRealPath(Activity activity, Uri uri) {
        try (android.database.Cursor cursor = activity.getContentResolver().query(
                uri,
                new String[]{MediaStore.Images.Media.DATA},
                null, null, null)) {
            if (cursor != null && cursor.moveToFirst()) {
                int col = cursor.getColumnIndexOrThrow(MediaStore.Images.Media.DATA);
                return cursor.getString(col);
            }
        } catch (Exception e) {
            // Fall back: copy to a temp file so Godot can read it
        }
        return copyToTempFile(activity, uri);
    }

    /** Copies the image to the app's cache dir and returns the path. */
    private String copyToTempFile(Activity activity, Uri uri) {
        try {
            java.io.File tmp = java.io.File.createTempFile(
                    "picked_", ".jpg", activity.getCacheDir());
            try (java.io.InputStream in  = activity.getContentResolver().openInputStream(uri);
                 java.io.OutputStream out = new java.io.FileOutputStream(tmp)) {
                if (in == null) return null;
                byte[] buf = new byte[4096];
                int n;
                while ((n = in.read(buf)) != -1) out.write(buf, 0, n);
            }
            return tmp.getAbsolutePath();
        } catch (Exception e) {
            return null;
        }
    }
}
