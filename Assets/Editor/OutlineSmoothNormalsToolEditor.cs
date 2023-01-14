using System.Collections;
using System.Collections.Generic;
using System.IO;
using UnityEditor;
using UnityEngine;

public class OutlineSmoothNormalsToolEditor : EditorWindow
{

    private enum EOverrideDataType
    {
        Tangent,
        Color,
        UV2,
        UV3,
        UV4
    }

    private enum ECompressType
    {
        None,
        TBN,
        FloatToHalf,
    }

    [MenuItem("Tools/Outline Smooth Normals Tool")]
    private static void Init()
    {
        OutlineSmoothNormalsToolEditor window = (OutlineSmoothNormalsToolEditor)EditorWindow.GetWindow(typeof(OutlineSmoothNormalsToolEditor));
        window.titleContent = new GUIContent("描边法线平滑工具");
        window.minSize = new Vector2(400,350);
        window.Show();
    }
    private Dictionary<int, Mesh> _smoothedNormalMap = new Dictionary<int, Mesh>();

    private void OnGUI()
    {
        GUIStyle style = new GUIStyle(GUI.skin.button);
        style.richText = true;
        GUILayout.Label("选择一个含有MeshFilter或SkinnedMeshRenderer的对象", EditorStyles.boldLabel);
        GUILayout.Space(10);
        EditorGUILayout.HelpBox("快速测试使用，重启Unity或者Reimport数据会丢失", MessageType.Info);
        if (GUILayout.Button("平滑法线并覆盖到<color=yellow>顶点切线数据</color>", style))
        {
            ProcessMesh(EOverrideDataType.Tangent, ECompressType.None, false);
        }
        if (GUILayout.Button("平滑法线并覆盖到<color=yellow>顶点颜色数据</color>", style))
        {
            ProcessMesh(EOverrideDataType.Color, ECompressType.None, false);
        }
        if (GUILayout.Button("平滑法线并压缩2个Float到1个的方式覆盖到<color=yellow>顶点UV3</color>", style))
        {
            ProcessMesh(EOverrideDataType.UV3, ECompressType.FloatToHalf,false);
        }
        if (GUILayout.Button("平滑法线并以切线空间的方式覆盖到<color=yellow>顶点UV3</color>", style))
        {
            ProcessMesh(EOverrideDataType.UV3, ECompressType.TBN, false);
        }

        EditorGUILayout.HelpBox("生成新的Mesh到 SmoothedNormalMesh 文件夹中并替换MeshFilter或者SkinnedMeshRenderer的sharedMesh为新Mesh，此方法不会丢失数据，如果新Mesh路径下已经有同名Mesh那么会直接覆盖", MessageType.Info);
        if (GUILayout.Button("平滑法线并覆盖到新生成的Mesh的<color=yellow>顶点切线数据</color>", style))
        {
            ProcessMesh(EOverrideDataType.Tangent, ECompressType.None, true);
        }
        if (GUILayout.Button("平滑法线并覆盖到新生成的Mesh的<color=yellow>顶点颜色数据</color>", style))
        {
            ProcessMesh(EOverrideDataType.Color, ECompressType.None, true);
        }
        if (GUILayout.Button("平滑法线并压缩2个Float到1个的方式覆盖到<color=yellow>顶点UV3</color>", style))
        {
            ProcessMesh(EOverrideDataType.UV3, ECompressType.FloatToHalf, true);
        }
        if (GUILayout.Button("平滑法线并以切线空间的方式覆盖到<color=yellow>顶点UV3</color>", style))
        {
            ProcessMesh(EOverrideDataType.UV3, ECompressType.TBN, true);
        }

    }

    private void ProcessMesh(EOverrideDataType type, ECompressType compressType, bool canCreateNewMesh)
    {
        _smoothedNormalMap.Clear();
        MeshFilter[] meshFilters = Selection.activeGameObject.GetComponentsInChildren<MeshFilter>();
        for (int i = 0; i < meshFilters.Length; ++i)
        {
            Mesh mesh = meshFilters[i].sharedMesh;
            if (mesh == null)
            {
                var name = AssetDatabase.GetAssetPath(meshFilters[i]);
                if (string.IsNullOrEmpty(name))
                    name = meshFilters[i].name;
                Debug.LogWarning(name + "的Mesh为Null处理被忽略");
                continue;
            }
            int instId = mesh.GetInstanceID();
            Mesh smoothedMesh;
            if (canCreateNewMesh)
            {
                if (_smoothedNormalMap.TryGetValue(instId, out smoothedMesh))
                {
                    meshFilters[i].sharedMesh = smoothedMesh;
                }
                else
                {
                    var newSmoothedMesh = ProcessSmoothMeshToNewMesh(type, compressType, mesh);
                    if (newSmoothedMesh != null)
                    {
                        meshFilters[i].sharedMesh = newSmoothedMesh;
                        _smoothedNormalMap.Add(instId, newSmoothedMesh);
                    }
                }
            }
            else
            {
                if (!_smoothedNormalMap.ContainsKey(instId))
                {
                    ProcessSmoothMesh(type, compressType, mesh);
                    _smoothedNormalMap.Add(instId, null);
                }
            }

        }

        SkinnedMeshRenderer[] skinMeshRenders = Selection.activeGameObject.GetComponentsInChildren<SkinnedMeshRenderer>();
        for (int i = 0; i < skinMeshRenders.Length; ++i)
        {
            Mesh mesh = skinMeshRenders[i].sharedMesh;
            if (mesh == null)
            {
                var name = AssetDatabase.GetAssetPath(skinMeshRenders[i]);
                if (string.IsNullOrEmpty(name))
                    name = skinMeshRenders[i].name;
                Debug.LogWarning(name + "的Mesh为Null处理被忽略");
                continue;
            }
            int instId = mesh.GetInstanceID();
            Mesh smoothedMesh;
            if (canCreateNewMesh)
            {
                if (_smoothedNormalMap.TryGetValue(instId, out smoothedMesh))
                {
                    skinMeshRenders[i].sharedMesh = smoothedMesh;
                }
                else
                {
                    var newSmoothedMesh = ProcessSmoothMeshToNewMesh(type, compressType, mesh);
                    if (newSmoothedMesh != null)
                    {
                        skinMeshRenders[i].sharedMesh = newSmoothedMesh;
                        _smoothedNormalMap.Add(instId, newSmoothedMesh);
                    }
                }
            }
            else
            {
                if (!_smoothedNormalMap.ContainsKey(instId))
                {
                    ProcessSmoothMesh(type, compressType, mesh);
                    _smoothedNormalMap.Add(instId, null);
                }
            }
        }
    }

    private void ProcessSmoothMesh(EOverrideDataType type, ECompressType compressType,Mesh mesh)
    {
        var smoothedNormals = GenerateSimpleAverageNormal(mesh);
        switch (type)
        {
            case EOverrideDataType.Tangent:
                mesh.SetTangents(ConvertSmoothedNormalToTangentData(mesh, smoothedNormals));
                break;
            case EOverrideDataType.Color:
                mesh.SetColors(ConvertSmoothedNormalToColorData(mesh, smoothedNormals));
                break;
            case EOverrideDataType.UV3:
                {
                    if (compressType == ECompressType.FloatToHalf)
                        mesh.SetUVs(2, ConvertCompressSmoothedNormalToUVData(mesh, smoothedNormals));
                    else if (compressType == ECompressType.TBN)
                        mesh.SetUVs(2, ConvertTangentSpaceSmoothedNormalToUVData(mesh, smoothedNormals));
                }
                break;
            default:
                break;
        }
    }

    private Mesh ProcessSmoothMeshToNewMesh(EOverrideDataType type, ECompressType compressType, Mesh mesh)
    {
        var smoothedNormals = GenerateSimpleAverageNormal(mesh);
        switch (type)
        {
            case EOverrideDataType.Tangent:
                {
                    var newMesh = CopyMeshDataToNewMesh(mesh);
                    newMesh.SetTangents(ConvertSmoothedNormalToTangentData(mesh, smoothedNormals));
                    return CreateNewMesh(newMesh, AssetDatabase.GetAssetPath(mesh));
                }
            case EOverrideDataType.Color:
                {
                    var newMesh = CopyMeshDataToNewMesh(mesh);
                    newMesh.SetColors(ConvertSmoothedNormalToColorData(mesh, smoothedNormals));
                    return CreateNewMesh(newMesh, AssetDatabase.GetAssetPath(mesh));
                }
            case EOverrideDataType.UV3:
                {
                    var newMesh = CopyMeshDataToNewMesh(mesh);
                    if(compressType == ECompressType.FloatToHalf)
                        newMesh.SetUVs(2, ConvertCompressSmoothedNormalToUVData(mesh, smoothedNormals));
                    else if(compressType == ECompressType.TBN)
                        newMesh.SetUVs(2, ConvertTangentSpaceSmoothedNormalToUVData(mesh, smoothedNormals));
                    return CreateNewMesh(newMesh, AssetDatabase.GetAssetPath(mesh));
                }
            default:
                break;
        }
        return null;
    }

    //收集的相同点（几个面共用的点），作为同一顶点组，然后求其法线的平均值并归一化
    //如果点是断开的可以考虑改为在某个距离内的点作为同一顶点组
    private Vector3[] GenerateSimpleAverageNormal(Mesh mesh)
    {
        var smoothNormalHash = new Dictionary<Vector3, Vector3>();
        var meshVertices = mesh.vertices;
        var meshNormals = mesh.normals;
        for (var j = 0; j < meshVertices.Length; j++)
        {
            if (!smoothNormalHash.ContainsKey(meshVertices[j]))
            {
                smoothNormalHash.Add(meshVertices[j], meshNormals[j].normalized);
            }
            else
            {
                smoothNormalHash[meshVertices[j]] = smoothNormalHash[meshVertices[j]] + meshNormals[j].normalized;
            }
        }
        var smoothNormalsArray = new Vector3[meshVertices.Length];
        for (var j = 0; j < meshVertices.Length; j++)
        {
            smoothNormalsArray[j] = smoothNormalHash[meshVertices[j]].normalized;
        }
        return smoothNormalsArray;
    }

    //组装要替换的切线数据
    private Vector4[] ConvertSmoothedNormalToTangentData(Mesh mesh,Vector3[] smoothNormals)
    {
        var newTangents = new Vector4[mesh.vertexCount];
        for (var j = 0; j < mesh.vertexCount; j++)
        {
            newTangents[j] = new Vector4(smoothNormals[j].x, smoothNormals[j].y, smoothNormals[j].z, 0);
        }
        return newTangents;
    }

    //组装要替换的颜色数据
    private Color[] ConvertSmoothedNormalToColorData(Mesh mesh, Vector3[] smoothNormals)
    {
        var newColors = new Color[mesh.vertexCount];
        for (var j = 0; j < mesh.vertexCount; j++)
        {
            newColors[j] = new Color(smoothNormals[j].x, smoothNormals[j].y, smoothNormals[j].z, 0);
        }
        return newColors;
    }

    //组装要替换的颜色数据
    //这里常见的3种方式
    //1.直接把平滑后的法线的Vector3写入UV，UV可以写Vector3和Vector4，优点：是直接取出来就能用，缺点：是会多1维的数据，
    //2.将平滑后的法线的xy压缩到1个维度，使Vector3变成Vector2，float是32位的，将xy2个float压缩到一个float也就是将float的16位给x另外16位给y，优点：写入UV只占2个维度，压缩和解压计算方便，缺点：精度丢了
    //3.将平滑后法线转换到切线空间，然后只保存xy，z在运行时通过xy计算出z，再从切线空间转换出来和2个通道的法线贴图一个原理，优点：只占UV的2个维度且没有精度损失，缺点：转换过程要有额外的运算
    //一般来说用2或3，因为1的写法对于顶点较多的模型来说，虽然只多了1维，但依然会写入非常多的数据
    //所以下面我把2和3都实现一遍方便学习

    //这里用2的方法实现,参考来自UnityCG.cginc的EncodeFloatRGBA函数和EncodeFloatRGBA函数，同样ToonyColorPro中也有类似的函数
    //在shadertoy可以快速实验自己的想法 https://www.shadertoy.com/view/4tGSW1
    //我们用类比将4个Float的颜色值存入一个Float的方法，我们将法线的当作颜色值，将x和y 2个Float存入一个Float，z放入另一个Float
    #region Toony Color Pro的做法
    /*
    //压缩
    static void GetCompressedSmoothedNormals(Vector3 smoothedNormal, out float x, out float y)
    {
        var _x = smoothedNormal.x * 0.5f + 0.5f;
        var _y = smoothedNormal.y * 0.5f + 0.5f;
        var _z = smoothedNormal.z * 0.5f + 0.5f;

        //pack x,y to uv2.x
        _x = Mathf.Round(_x * 15);
        _y = Mathf.Round(_y * 15);
        var packed = Vector2.Dot(new Vector2(_x, _y), new Vector2((float)(1.0 / (255.0 / 16.0)), (float)(1.0 / 255.0)));

        x = packed;
        y = _z;

    }
    //shader中的解码
    unpack()
    {
        #define ch1 x
        #define ch2 y

        float3 n;
        //unpack uvs
        input.uvChannel.ch1 = input.uvChannel.ch1 * 255.0 / 16.0;
        n.x = floor(input.uvChannel.ch1) / 15.0;
        n.y = frac(input.uvChannel.ch1) * 16.0 / 15.0;
        //- get z
        n.z = input.uvChannel.ch2;
        //- transform
        n = n * 2 - 1;
        float3 normal = n;

    }
    */
    #endregion
    private Vector2[] ConvertCompressSmoothedNormalToUVData(Mesh mesh, Vector3[] smoothNormals)
    {
        var newUVs = new Vector2[mesh.vertexCount];
        for (int i = 0; i < smoothNormals.Length; i++)
        {
            //平滑后的法线已经归一化，所以每个分量范围都是[-1,1]
            var smoothedNormal = smoothNormals[i];
            //将分量映射到[0,1]
            var x = smoothedNormal.x * 0.5f + 0.5f;
            var y = smoothedNormal.y * 0.5f + 0.5f;
            var z = smoothedNormal.z * 0.5f + 0.5f;

            //将[0,1]映射到颜色值对应的[0,255]整数,因为解码时，只针对小数，所以不能等于255，等于255会出现1.0，所以这里最大值是254
            x = Mathf.Min(Mathf.Round(x * 255), 254);
            y = Mathf.Min(Mathf.Round(y * 255), 254);

            //求出占255进制下的比例的小数，即255倍数，否则最后一步点乘加出来的数字，在解码时乘上65025后的值不对。
            //有些地方认为按255进制理解会好理解一些，但是我还是觉得单纯的从近似和解算的方式来理解
            //如果不四舍五入转为整数并重新/255得到近似的小数，随便拿一个小数的话，那么最后加在一起的packed，使x的部分和y混在一起，看起来貌似没问题
            //但当他们解算时同时乘65025，来取y时，因为x和y同时移动，随便拿的小数x不是255的整数得来的，所以会乘以255的倍数时，会有小数位和y混在一起，即无法正确取出y，也导致x无法正确取出
            //如果时近似的整数/255得来的x和y的话，那么乘以65025时我们可以在获取小数时得到正确的y
            x /= 255;
            y /= 255;

            //点乘就是 x1*x2+y1*y2
            //65025.0f 是255的平方
            //我们用加法将x和y加在一起，所以需要错开x和y
            //[0-255^2]留给x，然后255^2后面留给y
            var packed = Vector2.Dot(new Vector2(x, y), new Vector2(1.0f, 1.0f / 65025.0f));

            x = packed;
            y = z;
            newUVs[i] = new Vector2(x, y);
        }
        return newUVs;
    }


    //这里用3的方法实现 因为是法线单位向量，所以存的是xy还原的时候，只需要 z = sqrt(1 - x^2 - y^2)就可以算出来z，这就是向量的模长公式，1 = sqrt( x^2 + y^2 + z^2 )，推出来即可
    //因为切线空间z总是正数，所以求出来的z就是我们要的,不用管方向
    private Vector2[] ConvertTangentSpaceSmoothedNormalToUVData(Mesh mesh, Vector3[] smoothNormals)
    {
        Vector4[] meshTangents = mesh.tangents;
        Vector3[] meshNormals = mesh.normals;
        for (int i = 0; i < smoothNormals.Length; i++)
        {
            //构建TBN变换矩阵，与紫色的法线贴图的特性和从切线空间转换到世界空间一样，现在我们反过来把模型空间平滑过的法线转到切线空间
            Vector3 tangent = new Vector3(meshTangents[i].x, meshTangents[i].y, meshTangents[i].z);
            Vector3 normal = meshNormals[i].normalized;
            Vector3 biNormal = Vector3.Cross(normal, tangent).normalized * meshTangents[i].w;

            Matrix4x4 tbnMatrix = Matrix4x4.zero;
            tbnMatrix.SetRow(0, tangent);
            tbnMatrix.SetRow(1, biNormal);
            tbnMatrix.SetRow(2, normal);
            smoothNormals[i] = tbnMatrix * smoothNormals[i].normalized;
            smoothNormals[i] = smoothNormals[i].normalized;
        }

        var newUVs = new Vector2[mesh.vertexCount];
        for (var j = 0; j < mesh.vertexCount; j++)
        {
            newUVs[j] = new Vector2(smoothNormals[j].x, smoothNormals[j].y);
        }
        return newUVs;
    }



    private Mesh CopyMeshDataToNewMesh(Mesh orgMesh)
    {
        Mesh newMesh = Instantiate<Mesh>(orgMesh);
        newMesh.name = orgMesh.name;
        return newMesh;
    }
    private Mesh CreateNewMesh(Mesh mesh,string path)
    {
        var assetPathPrefix = "Assets/";
        var filePath = path.Remove(0, assetPathPrefix.Length);
        var relativeRootPath = "SmoothedNormalMesh/";
        var relativePath = Path.GetDirectoryName(filePath) + "/" + Path.GetFileNameWithoutExtension(filePath) + "/";
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
        var targetFileName = mesh.name + "[copy].asset";
        var targetFilePath = assetsPath + targetFileName;
        var fullTargetFilePath = rootPath + targetFileName;
        if (File.Exists(fullTargetFilePath))
        {
            AssetDatabase.DeleteAsset(targetFilePath);
        }
        AssetDatabase.CreateAsset(mesh, targetFilePath);
        AssetDatabase.Refresh();
        return mesh;
    }
}
