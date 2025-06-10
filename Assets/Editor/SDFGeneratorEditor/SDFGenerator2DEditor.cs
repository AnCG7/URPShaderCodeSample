using SDFGenerator2D;
using System.Collections;
using System.Collections.Generic;
using System.IO;
using UnityEditor;
using UnityEditorInternal;
using UnityEngine;

public class SDFGenerator2DEditor : EditorWindow
{
    private class TextureCellData
    {
        public Texture2D srcTexture;
        public int targetWidth = 16;
        public int targetHeight = 16;
        public EColorChannel srcColorChannel = EColorChannel.A;
        public EColorChannel targetColorChannel = EColorChannel.A;
        public Texture2D targetTexutre;
    }

    private class TexturePropertyRecordData
    {
        public Texture2D texture;
        public bool isReadble;
        public TextureImporterCompression compressionType;
        public bool isCrunchedCompress;
        public int compressionQuality;
    }

    [MenuItem("Tools/SDF Generator 2D")]
    private static void Init()
    {
        SDFGenerator2DEditor window = (SDFGenerator2DEditor)EditorWindow.GetWindow(typeof(SDFGenerator2DEditor));
        window.titleContent = new GUIContent("SDF 2D生成工具");
        window.minSize = new Vector2(500,350);
        window.Show();
    }

    private ReorderableList _reorderableList;
    private List<TextureCellData> _texCellDataList = new List<TextureCellData>();
    private List<TexturePropertyRecordData> _texPropertyRecordList = new List<TexturePropertyRecordData>();
    private Vector2 _scrollPosition;
    private const int REORDERABLELIST_ELE_HEIGHT = 80;
    private void OnEnable()
    {
        if (_texCellDataList.Count == 0)
        {
            _texCellDataList.Add(new TextureCellData());
        }
        _texPropertyRecordList.Clear();
        _reorderableList = new ReorderableList(_texCellDataList,typeof(TextureCellData), true, true, true, true);
        _reorderableList.drawHeaderCallback = OnReorderableListDrawHeader;
        _reorderableList.drawElementCallback = OnReorderableListDrawElement;
        _reorderableList.onCanRemoveCallback = OnReorderableListCanRemove;
        _reorderableList.elementHeight = REORDERABLELIST_ELE_HEIGHT;
    }

    private void OnDisable()
    {

    }
    private void OnReorderableListDrawHeader(Rect rect)
    {
        EditorGUI.LabelField(rect, "总数:"+ _texCellDataList.Count);
    }
    private bool OnReorderableListCanRemove(ReorderableList list)
    {
        return _texCellDataList.Count > 1;
    }
    private void OnReorderableListDrawElement(Rect rect, int index, bool isActive, bool isFocused)
    {
        Rect org = rect;
        float fieldHeight = 20;
        float fieldHInvertal = 2;
        float fieldVInvertal = 5;

        
        TextureCellData data = _texCellDataList[index];
        org.width = REORDERABLELIST_ELE_HEIGHT - 20;
        org.height = REORDERABLELIST_ELE_HEIGHT - 20;
        org.x = rect.width - org.width;
        org.y = rect.height * 0.5f - org.height * 0.5f + rect.y;
        data.srcTexture = (Texture2D)EditorGUI.ObjectField(org, data.srcTexture, typeof(Texture2D),false);

        org.y = rect.y + fieldHInvertal + 10;
        org.x = rect.x;
        org.height = fieldHeight;
        org.width = 50;
        EditorGUI.LabelField(org, "源通道");
        org.x += 50 + fieldVInvertal;
        org.width = 50;
        data.srcColorChannel = (EColorChannel)EditorGUI.EnumPopup(org, data.srcColorChannel);

        org.x -= 50 + fieldVInvertal;
        org.y += 20 + fieldHInvertal;
        org.width = 50;
        EditorGUI.LabelField(org, "目标通道");
        org.x += 50 + fieldVInvertal;
        org.width = 50;
        data.targetColorChannel = (EColorChannel)EditorGUI.EnumPopup(org, data.targetColorChannel);

        org.x = rect.x;
        org.y += fieldHeight + fieldHInvertal;
        org.height = fieldHeight;
        org.width = 50;
        EditorGUI.LabelField(org, "目标尺寸");
        org.x += 50 + fieldVInvertal;
        org.width = 50;
        
        data.targetWidth = data.targetHeight = Mathf.Max(1, EditorGUI.IntField(org, data.targetWidth));

    }

    private void OnGUI()
    {

        var height = Mathf.Min(_reorderableList.GetHeight(), 4 * REORDERABLELIST_ELE_HEIGHT);
        _scrollPosition = GUILayout.BeginScrollView(_scrollPosition, GUILayout.Height(height));
        _reorderableList.DoLayoutList();
        GUILayout.EndScrollView();

        if (GUILayout.Button("生成使用8ssedt(SDF)"))
        {
            GenerateWithCPU();
        }
        if (GUILayout.Button("生成使用ComputeShader使用JFA(DF)"))
        {
            GenerateWithGPU();
        }
    }

    private void GenerateWithCPU()
    {
        bool isError = CheckTextureValid();
        if (isError) return;
        try
        {
            EditorUtility.DisplayProgressBar("提示", "生成SDF 2D中", 0);
            TryCorrectTexutreProperty();
            EditorUtility.DisplayProgressBar("提示", "生成SDF 2D中", 0.1f);
            GenrateTargetTexture();
            EditorUtility.DisplayProgressBar("提示", "生成SDF 2D中", 0.2f);
            GenrateSDFWithCPU();
            EditorUtility.DisplayProgressBar("提示", "生成SDF 2D中", 0.9f);
            SaveAllTexture();
            EditorUtility.DisplayProgressBar("提示", "生成SDF 2D中", 1);
            
        }
        finally
        {
            ReverseTexutreProperty();
            EditorUtility.ClearProgressBar();
        }
    }
    
    private void GenerateWithGPU()
    {
        bool isError = CheckTextureValid();
        if (isError) return;
        try
        {
            EditorUtility.DisplayProgressBar("提示", "生成SDF 2D中", 0);
            TryCorrectTexutreProperty();
            EditorUtility.DisplayProgressBar("提示", "生成SDF 2D中", 0.1f);
            GenrateTargetTexture();
            EditorUtility.DisplayProgressBar("提示", "生成SDF 2D中", 0.2f);
            GenrateSDFWithGPU();
            EditorUtility.DisplayProgressBar("提示", "生成SDF 2D中", 0.9f);
            SaveAllTexture();
            EditorUtility.DisplayProgressBar("提示", "生成SDF 2D中", 1);
            
        }
        finally
        {
            ReverseTexutreProperty();
            EditorUtility.ClearProgressBar();
        }
    }

    private bool CheckTextureValid()
    {
        bool isError = false;
        for (int i = 0; i < _texCellDataList.Count; ++i)
        {
            var cellData = _texCellDataList[i];
            if (cellData == null) { isError = true; break; }
            if (cellData.srcTexture == null) { isError = true; break; }
        }
        if (isError)
        {
            EditorUtility.DisplayDialog("错误", "资源为空，请检查！", "确定");
        }
        return isError;
    }

    private void TryCorrectTexutreProperty()
    {
        _texPropertyRecordList.Clear();
        for (int i = 0; i < _texCellDataList.Count; ++i)
        {
            var cellData = _texCellDataList[i];
            if (cellData == null) return;
            Texture2D texture = cellData.srcTexture;
            if (texture != null)
            {
                string path = AssetDatabase.GetAssetPath(texture);
                TextureImporter importer = TextureImporter.GetAtPath(path) as TextureImporter;
                if (importer != null)
                {

                    bool isReadble = importer.isReadable;
                    bool isCompress = importer.textureCompression != TextureImporterCompression.Uncompressed;
                    bool isCrunchedCompress = importer.crunchedCompression;
                    int compressionQuality = importer.compressionQuality;

                    if (!isReadble || isCompress)
                    {
                        //图片属性错误的存下来，后面还原用
                        var propRecode = new TexturePropertyRecordData();
                        propRecode.texture = texture;
                        propRecode.isReadble = isReadble;
                        propRecode.compressionType = importer.textureCompression;
                        propRecode.isCrunchedCompress = isCrunchedCompress;
                        propRecode.compressionQuality = compressionQuality;
                        _texPropertyRecordList.Add(propRecode);

                        //纠正图片属性
                        importer.isReadable = true;
                        importer.textureCompression = TextureImporterCompression.Uncompressed;
                        importer.crunchedCompression = false;
                        AssetDatabase.ImportAsset(path);
                    }
                }
            }
        }
    }

    private void ReverseTexutreProperty()
    {
        for (int i = 0; i < _texPropertyRecordList.Count; ++i)
        {
            var propRecord = _texPropertyRecordList[i];
            if (propRecord != null)
            {
                if (propRecord.texture != null)
                {
                    string path = AssetDatabase.GetAssetPath(propRecord.texture);
                    TextureImporter importer = TextureImporter.GetAtPath(path) as TextureImporter;
                    if (importer != null)
                    {
                        importer.isReadable = propRecord.isReadble;
                        importer.textureCompression = propRecord.compressionType;
                        importer.crunchedCompression = propRecord.isCrunchedCompress;
                        importer.compressionQuality = propRecord.compressionQuality;
                        AssetDatabase.ImportAsset(path);
                    }
                }
            }
        }
    }
    private void GenrateTargetTexture()
    {
        for (int i = 0; i < _texCellDataList.Count; ++i)
        {
            var cellData = _texCellDataList[i];
            if (cellData != null)
            {
                var targetTexutre = new Texture2D(cellData.targetWidth, cellData.targetHeight, TextureFormat.ARGB32, false);
                cellData.targetTexutre = targetTexutre;
            }
        }
    }

    private void GenrateSDFWithCPU()
    {
        var sdfCore = new SDF8ssedt(); 
        for (int i = 0; i < _texCellDataList.Count; ++i)
        {
            var cellData = _texCellDataList[i];
            if (cellData != null && cellData.srcTexture != null && cellData.targetTexutre != null)
            {
                sdfCore.Generate(cellData.srcTexture, cellData.targetTexutre, cellData.srcColorChannel, cellData.targetColorChannel);
                cellData.targetTexutre.Apply();
            }
        }
    }

    /// <summary>
    /// 未开发，此只作为顺带的JFA算法示例，可生成距离场，有向距离场需要额外处理
    /// </summary>
    private void GenrateSDFWithGPU()
    {
        var sdfCore = new SDFJFA();
        for (int i = 0; i < _texCellDataList.Count; ++i)
        {
            var cellData = _texCellDataList[i];
            if (cellData != null && cellData.srcTexture != null && cellData.targetTexutre != null)
            {
                sdfCore.Generate(cellData.srcTexture, cellData.targetTexutre, cellData.srcColorChannel, cellData.targetColorChannel);
                cellData.targetTexutre.Apply();
                
            }
        }
    }

    private void SaveAllTexture()
    {
        for (int i = 0; i < _texCellDataList.Count; ++i)
        {
            var cellData = _texCellDataList[i];
            if (cellData != null && cellData.srcTexture != null && cellData.targetTexutre != null)
            {
                var path = AssetDatabase.GetAssetPath(cellData.srcTexture);
                SaveTexture(path,cellData.targetTexutre);
            }
        }
    }
    private void SaveTexture(string path,Texture2D texture)
    {
        if (texture == null || string.IsNullOrEmpty(path)) return;

        var assetPathPrefix = "Assets/";
        var filePath = path.Remove(0, assetPathPrefix.Length);
        var relativeRootPath = "SDFGenerated/";
        var fileName = Path.GetFileNameWithoutExtension(filePath);
        var relativePath = Path.GetDirectoryName(filePath) + "/";
        if (!filePath.StartsWith(relativeRootPath))
        {
            relativePath = relativeRootPath + relativePath;
        }

        var assetsPath = assetPathPrefix + relativePath;
        var rootPath = Application.dataPath + "/" + relativePath;
        if (!Directory.Exists(rootPath))
        {
            Directory.CreateDirectory(rootPath);
        }
        var targetFileName = fileName + "_SDF" + ".png";
        var relativeTargetFilePath = assetsPath + targetFileName;
        var fullTargetFilePath = rootPath + targetFileName;
        if (File.Exists(fullTargetFilePath))
        {
            AssetDatabase.DeleteAsset(relativeTargetFilePath);
        }
        File.WriteAllBytes(fullTargetFilePath, texture.EncodeToPNG());

        AssetDatabase.Refresh();

        TextureImporter importer = TextureImporter.GetAtPath(relativeTargetFilePath) as TextureImporter;
        if (importer != null)
        {
            importer.textureCompression = TextureImporterCompression.Uncompressed;
            AssetDatabase.ImportAsset(path);
        }

       
    }
}
