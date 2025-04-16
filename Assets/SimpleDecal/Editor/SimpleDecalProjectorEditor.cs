using System;
using System.Collections.Generic;
using System.Reflection;
using UnityEditor;
using UnityEditor.Rendering;
using UnityEngine;
using UnityEngine.Rendering.Universal;

[CustomEditor(typeof(SimpleDecalProjector))]
[CanEditMultipleObjects]
public class SimpleDecalProjectorEditor : Editor
{
    // 编辑器脚本，用于在启动时设置图标
    [InitializeOnLoad]
    private class SimpleDecalProjectorEditorIcon
    {
        static SimpleDecalProjectorEditorIcon()
        {
            Texture2D icon =
                AssetDatabase.LoadAssetAtPath<Texture2D>("Assets/SimpleDecal/Editor/Resources/CustomDecalGizmo.png");
            if (icon != null)
            {
                SimpleDecalProjector[] monoBehaviours = Resources.FindObjectsOfTypeAll<SimpleDecalProjector>();
                foreach (SimpleDecalProjector monoBehaviour in monoBehaviours)
                {
                    EditorGUIUtility.SetIconForObject(monoBehaviour, icon);
                }
            }
        }
    }

    private const float HANDLE_SIZE = 0.04f;
    private static readonly Color UNSELECT_WIRE_COLOR = new Color(1, 1, 1, 0.25f);
    private static readonly Color SELECTED_WIRE_COLOR = new Color(1, 1, 1, 0.85f);
    private static readonly Color HANDLE_COLOR = new Color(1, 1, 1, 0.9f);
    private static readonly Color UNSELECT_ARROW_COLOR = new Color(1, 1, 1, 0.5f);
    private static readonly Color SELECTED_ARROW_COLOR = new Color(1, 1, 1, 1f);
    private static readonly Color GIZMO_UNSELECT_ARROW_COLOR = new Color(0, 0, 1, 0.5f);
    private static readonly Color GIZMO_SELECTED_ARROW_COLOR = new Color(0, 0, 1, 1f);

    // 绘制5个面的控制柄,背面不没有控制柄，因为轴点在背面，背面有控制柄不好控制
    private static readonly Vector3[] _faceCenters =
    {
        new Vector3(0.5f, 0, 0),
        new Vector3(-0.5f, 0, 0),
        new Vector3(0, 0.5f, 0),
        new Vector3(0, -0.5f, 0),
        new Vector3(0, 0, 0.5f) //正面
    };

    //绘制线框和箭头 
    [DrawGizmo(GizmoType.NonSelected | GizmoType.Selected | GizmoType.Pickable)]
    private static void DrawGizmos(SimpleDecalProjector projector, GizmoType gizmoType)
    {
        var isSelected = (gizmoType & GizmoType.Selected) != 0;
        var handleMatrix = GetBoxMatrix(projector);
        var boxCenter = GetBoxLocalCenter(projector);
        DrawGizmoBox(projector, handleMatrix, boxCenter, isSelected);
        if (!isSelected)
        {
            DrawGizmoArrow(projector, handleMatrix, isSelected);
        }

        Gizmos.DrawIcon(projector.transform.position, "Assets/Decal/Editor/Resources/CustomDecalGizmo.png");
    }

    
    private SerializedProperty _decalMaterial;
    private SerializedProperty _degreeThreshold;
    private SerializedProperty _decalScale;
    private SerializedProperty _decalBoxSize;
    private SerializedProperty _drawOrder;
    private SerializedProperty _renderingLayerMask;
    private SerializedProperty _script;
    private MaterialEditor _materialEditor;
    private Material _defaultMaterial;
    private void OnEnable()
    {
        
        _decalMaterial = serializedObject.FindProperty("_decalMaterial");
        _degreeThreshold = serializedObject.FindProperty("_degreeThreshold");
        _decalScale = serializedObject.FindProperty("_decalScale");
        _decalBoxSize = serializedObject.FindProperty("_boxSize");
        _drawOrder = serializedObject.FindProperty("_drawOrder");
        _renderingLayerMask = serializedObject.FindProperty("_renderingLayerMask");
        _script = serializedObject.FindProperty("m_Script");
        if (_defaultMaterial == null)
        {
            _defaultMaterial = AssetDatabase.LoadAssetAtPath<Material>("Assets/SimpleDecal/DefaultDecal.mat");
        }
        UpdateMaterialEditor();
    }

    private void OnDestroy()
    {
        if (_materialEditor!= null)
        {
            DestroyImmediate(_materialEditor);
            _materialEditor = null;
        }
    }


    //选中的时候走这里 
    private void OnSceneGUI()
    {
        SimpleDecalProjector projector = target as SimpleDecalProjector;
        var boxCenter = GetBoxLocalCenter(projector);
        var handleMatrix = GetBoxMatrix(projector);
        DrawHanlder(projector, handleMatrix, boxCenter);
        DrawArrow(projector, handleMatrix, true);
        SceneView.RepaintAll();
    }

    public override void OnInspectorGUI()
    {
        EditorGUI.BeginDisabledGroup(true);
        EditorGUILayout.PropertyField(_script);
        EditorGUI.EndDisabledGroup();
        
        serializedObject.Update();
        bool materialChanged = false;
        bool isDefaultMaterial = false;
        bool isValidDecalMaterial = true;
        if (!CheckForCustomFeature(UniversalRenderPipeline.asset))
        {
            CoreEditorUtils.DrawFixMeBox("需要添加SimpleDecalRendererFeature才能正常运行", MessageType.Warning, "Open", () =>
            {
                //scriptableRendererData是internal修饰，无法直接访问，这里通过反射访问
                // var asset = UniversalRenderPipeline.asset.scriptableRendererData;
                var asset = UniversalRenderPipeline.asset;
                if (asset != null)
                {
                    //通过反射调用scriptableRendererData
                    var scriptableRendererDataField = asset.GetType().GetProperty("scriptableRendererData", BindingFlags.Instance | BindingFlags.NonPublic|BindingFlags.Public);
                    if (scriptableRendererDataField != null)
                    {
                        var obj = scriptableRendererDataField.GetValue(asset) as ScriptableRendererData;
                        if (obj != null)
                        {
                            Selection.activeObject = obj;
                            GUIUtility.ExitGUI();
                        }
                    }
                }
            });
        }
        
        EditorGUI.BeginChangeCheck();
        EditorGUILayout.PropertyField(_decalMaterial);
        materialChanged = EditorGUI.EndChangeCheck();

        EditorGUILayout.PropertyField(_degreeThreshold);
        EditorGUILayout.PropertyField(_decalScale);
        EditorGUILayout.PropertyField(_decalBoxSize);
        EditorGUILayout.PropertyField(_drawOrder);
        // 单独绘制渲染层遮罩
        //EditorUtils是UnityEditor.Rendering.Universal的一个internal类无法直接访问，这里通过反射访问,来绘制RenderingLayerMask
        //EditorUtils.DrawRenderingLayerMask(_renderingLayerMask, new GUIContent("Rendering Layer Mask"));
        Type editorUtilsType = Type.GetType("UnityEditor.Rendering.Universal.EditorUtils, Unity.RenderPipelines.Universal.Editor");
        if (editorUtilsType != null)
        {
            // 获取DrawRenderingLayerMask方法的信息
            var drawRenderingLayerMaskMethod = editorUtilsType.GetMethod("DrawRenderingLayerMask", BindingFlags.Static | BindingFlags.NonPublic|BindingFlags.Public);
            if (drawRenderingLayerMaskMethod != null)
            {
                // 调用DrawRenderingLayerMask方法
                drawRenderingLayerMaskMethod.Invoke(null, new object[] { _renderingLayerMask, new GUIContent("Rendering Layer Mask") });
            }
        }
        
        var decalProjector = target as SimpleDecalProjector;
        var mat = decalProjector.decalMaterial;
        if (mat == null)
        {
            _decalMaterial.objectReferenceValue = _defaultMaterial;
            decalProjector.decalMaterial = _defaultMaterial; // 确保材质被设置为默认材质
            materialChanged = true;
        }

        isDefaultMaterial = decalProjector.decalMaterial == _defaultMaterial;
        isValidDecalMaterial = decalProjector.IsValidMaterial();
        
        if (_materialEditor && !isValidDecalMaterial)
        {
            CoreEditorUtils.DrawFixMeBox("只能使用贴花的材质. 使用默认的可用贴花材质替换", () =>
            {
                _decalMaterial.objectReferenceValue = _defaultMaterial;
                decalProjector.decalMaterial = _defaultMaterial; // 确保材质被设置为默认材质
                materialChanged = true;
            });
        }
        serializedObject.ApplyModifiedProperties();

        if (materialChanged)
        {
            UpdateMaterialEditor();
        }
        if (_materialEditor != null)
        {
            if (isValidDecalMaterial)
            {
                EditorGUILayout.Space();
                using (new EditorGUI.DisabledGroupScope(isDefaultMaterial))
                {
                    _materialEditor.DrawHeader();
                    _materialEditor.OnInspectorGUI();
                }
            }
        }
    }
    
    private bool CheckForCustomFeature(UniversalRenderPipelineAsset pipelineAsset)
    {
        // 获取所有的渲染器数据
        ScriptableRenderer renderer = pipelineAsset.scriptableRenderer;
        // 获取渲染器数据中的所有渲染功能,rendererFeatures属性是受保护的，无法直接访问，这里通过反射访问，这个版本很多应该开放的，都没有开放，所以只能通过反射访问
        //List<ScriptableRendererFeature> features = rendererData.rendererFeatures;
        var featuresField = renderer.GetType().GetProperty("rendererFeatures", BindingFlags.Instance | BindingFlags.NonPublic|BindingFlags.Public);
        if (featuresField != null)
        {
            var features = featuresField.GetValue(renderer) as List<ScriptableRendererFeature>;
            if (features != null)
            {
                foreach (ScriptableRendererFeature feature in features)
                {
                    if (feature is SimpleDecalRendererFeature)
                    {
                        return true;
                    }
                }   
            }
        }
        return false;
    }
    private void UpdateMaterialEditor()
    {
        int validMaterialsCount = 0;
        for (int index = 0; index < targets.Length; ++index)
        {
            SimpleDecalProjector decalProjector = (targets[index] as SimpleDecalProjector);
            if ((decalProjector != null) && (decalProjector.decalMaterial != null))
                validMaterialsCount++;
        }
        UnityEngine.Object[] materials = new UnityEngine.Object[validMaterialsCount];
        validMaterialsCount = 0;
        for (int index = 0; index < targets.Length; ++index)
        {
            SimpleDecalProjector decalProjector = (targets[index] as SimpleDecalProjector);

            if ((decalProjector != null) && (decalProjector.decalMaterial != null))
                materials[validMaterialsCount++] = (targets[index] as SimpleDecalProjector).decalMaterial;
        }
        _materialEditor = (MaterialEditor)CreateEditor(materials);
    }
    
    private static Matrix4x4 GetBoxMatrix(SimpleDecalProjector projector)
    {
        Transform transform = projector.transform;
        // 创建忽略缩放的变换矩阵 
        Matrix4x4 handleMatrix = Matrix4x4.TRS(
            transform.position,
            transform.rotation,
            Vector3.one // 强制缩放为1 
        );
        return handleMatrix;
    }

    private static Vector3 GetBoxLocalCenter(SimpleDecalProjector projector)
    {
        //为了方便理解，偏移一下后面的box面作为中心而不是box的几何正中心作为中心，毕竟投影是从一侧往另一个测投射
        var boxCenter = new Vector3(0, 0, projector.boxSize.z * 0.5f);
        return boxCenter;
    }

    private static void DrawBox(SimpleDecalProjector projector, Matrix4x4 handleMatrix, Vector3 localCenter,
        bool isSelected)
    {
        using (new Handles.DrawingScope(handleMatrix))
        {
            // 绘制带旋转的线框Box（使用projector.boxSize 控制尺寸）
            var color = UNSELECT_WIRE_COLOR;
            if (isSelected)
            {
                color = SELECTED_WIRE_COLOR;
            }

            Handles.color = color;
            var boxSize = projector.boxSize;
            Handles.DrawWireCube(localCenter, boxSize);
        }
    }

    private static void DrawHanlder(SimpleDecalProjector projector, Matrix4x4 handleMatrix, Vector3 localBoxCenter)
    {
        var boxSize = projector.boxSize;
        using (new Handles.DrawingScope(handleMatrix))
        {
            EditorGUI.BeginChangeCheck();
            for (int i = 0; i < _faceCenters.Length; i++)
            {
                // 将局部坐标转换为带旋转的全局坐标 
                Vector3 dir = _faceCenters[i].normalized;
                Vector3 pos = localBoxCenter + Vector3.Scale(_faceCenters[i], projector.boxSize);

                Handles.color = HANDLE_COLOR;
                float handleSize = HandleUtility.GetHandleSize(pos) * HANDLE_SIZE;
                Vector3 newPos = Handles.FreeMoveHandle(pos, handleSize, Vector3.zero, Handles.DotHandleCap);
                // 计算尺寸变化 
                if (EditorGUI.EndChangeCheck())
                {
                    Undo.RecordObject(projector, "Change Decal Size");
                    Vector3 delta = newPos - pos;
                    var scale = 1;
                    if (i != 4) //4是正面只有一个控制点不需要2倍
                    {
                        scale = 2;
                    }

                    boxSize += Vector3.Scale(delta, dir) * scale;
                    projector.boxSize = Vector3.Max(boxSize, Vector3.zero);
                }
            }
        }
    }

    private static void DrawArrow(SimpleDecalProjector projector, Matrix4x4 handleMatrix, bool isSelected)
    {
        var boxSize = projector.boxSize;
        using (new Handles.DrawingScope(handleMatrix))
        {
            var color = UNSELECT_ARROW_COLOR;
            if (isSelected)
            {
                color = SELECTED_ARROW_COLOR;
            }

            Handles.color = color;
            Handles.ArrowHandleCap(
                0,
                Vector3.zero,
                Quaternion.identity,
                boxSize.z * 0.3f,
                EventType.Repaint
            );
        }
    }

    private static void DrawGizmoBox(SimpleDecalProjector projector, Matrix4x4 handleMatrix, Vector3 localCenter,
        bool isSelected)
    {
        Gizmos.matrix = handleMatrix;
        // 绘制带旋转的线框Box（使用projector.boxSize 控制尺寸）
        var color = UNSELECT_WIRE_COLOR;
        if (isSelected)
        {
            color = SELECTED_WIRE_COLOR;
        }

        Gizmos.color = color;
        var boxSize = projector.boxSize;
        Gizmos.DrawWireCube(localCenter, boxSize);
    }

    private static void DrawGizmoArrow(SimpleDecalProjector projector, Matrix4x4 handleMatrix, bool isSelected)
    {
        var boxSize = projector.boxSize;
        var color = GIZMO_UNSELECT_ARROW_COLOR;
        if (isSelected)
        {
            color = GIZMO_SELECTED_ARROW_COLOR;
        }

        Gizmos.matrix = handleMatrix;
        Gizmos.color = color;
        Vector3 start = Vector3.zero;
        Vector3 end = new Vector3(0, 0, boxSize.z * 0.4f);

        // 绘制箭头
        Gizmos.DrawLine(start, end);
    }
}



