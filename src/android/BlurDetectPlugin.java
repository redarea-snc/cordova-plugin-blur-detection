package org.apache.cordova.blurdetect;

import org.json.JSONObject;
import org.opencv.android.OpenCVLoader;
import org.opencv.android.Utils;
import org.opencv.core.Core;
import org.opencv.core.CvType;
import org.opencv.core.Mat;
import org.opencv.core.MatOfDouble;
import org.opencv.imgproc.Imgproc;

import org.apache.cordova.CallbackContext;
import org.apache.cordova.CordovaPlugin;
import org.json.JSONArray;
import org.json.JSONException;

import android.Manifest;
import android.annotation.SuppressLint;
import android.content.pm.PackageManager;

import android.graphics.Bitmap;
import android.graphics.BitmapFactory;

import java.text.DecimalFormat;

/**
 * This class exposes methods in Cordova that can be called from JavaScript.
 */
public class BlurDetectPlugin extends CordovaPlugin {

    public String _imageUri;
    public CallbackContext _callbackContext;
    private static final int WRITE_EXTERNAL_STORAGE_PERMISSION = 0;

    /**
     * Executes the request and returns PluginResult.
     *
     * @param action          The action to execute.
     * @param args            JSONArry of arguments for the plugin.
     * @param callbackContext The callback context from which we were invoked.
     */
    @SuppressLint("NewApi")
    public boolean execute(String action, final JSONArray args, final CallbackContext callbackContext) throws JSONException {
        if (action.equals("checkImage")) {
            OpenCVLoader.initDebug();

            JSONObject obj = new JSONObject(args.getString(0));
            String imageUri = obj.getString("uri");
            _imageUri = imageUri;
            _callbackContext = callbackContext;
            this.cordova.requestPermissions(this, 0, new String[]{Manifest.permission.WRITE_EXTERNAL_STORAGE});
//            imageProcess(); Lo chiama direttamente onPermissionRequestResult
            return true;
        }
        return false;
    }

    private void imageProcess() {
        Bitmap originalBmp = BitmapFactory.decodeFile(_imageUri);
        if (originalBmp == null) {
            _callbackContext.error("CANNOT OPEN IMAGE!");
        } else {
            Mat destination = new Mat();
            Mat matGray = new Mat();
            Mat image = new Mat();
            Utils.bitmapToMat(originalBmp, image);
            Imgproc.cvtColor(image, matGray, Imgproc.COLOR_BGR2GRAY);
            Imgproc.Laplacian(matGray, destination, CvType.CV_64F);
            MatOfDouble median = new MatOfDouble();
            MatOfDouble std = new MatOfDouble();
            Core.meanStdDev(destination, median, std);
            double result = Math.pow(std.get(0, 0)[0], 2.0);

            //return DecimalFormat("0.00").format(Math.pow(std.get(0, 0)[0], 2.0)).toDouble()
            String textResult = (new DecimalFormat("0.00")).format(result);
            _callbackContext.success(textResult);            
        }
    }

    public void onRequestPermissionResult(int requestCode, String[] permissions, int[] grantResults) throws JSONException {
        for (int r : grantResults) {
            if (r == PackageManager.PERMISSION_DENIED) {
                _callbackContext.error("PERMISSION DENIED");
                return;
            }
        }

        switch (requestCode) {
            case WRITE_EXTERNAL_STORAGE_PERMISSION:
                //Do not block the core thread
                cordova.getThreadPool().execute(new Runnable() {
                    public void run() {
                        imageProcess();
                    }
                });
                break;
        }
    }
}