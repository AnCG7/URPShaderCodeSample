using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEditor;
using System.IO;

[InitializeOnLoad]
public static class CaptureScreenshotEditor
{
    [MenuItem("Tools/Capture Screenshot %&s")]
    public static void CaptureScreenshot()
    {
        string path = Application.dataPath + "/../Screenshot/";
        if (!Directory.Exists(path))
        {
            Directory.CreateDirectory(path);
        }
        string name = "Screenshot" + System.DateTime.Now.ToString("yyyyMMddHHmmssffff") + ".png";
        ScreenCapture.CaptureScreenshot(path+name, 1);
        Debug.Log("Screenshot Path : "+path + name);
    }
}
