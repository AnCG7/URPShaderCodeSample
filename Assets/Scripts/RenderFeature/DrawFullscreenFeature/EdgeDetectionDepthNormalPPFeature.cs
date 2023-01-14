//Blit参考 https://github.com/Unity-Technologies/UniversalRenderingExamples 的 DrawFullscreenFeature、DrawFullscreenPass和编辑器代码DrawFullScreenFeatureDrawer
//更多参考Unity自带的RenderObjects.cs等

using UnityEngine;
using UnityEngine.Rendering.Universal;

public class EdgeDetectionDepthNormalPPFeature : ScriptableRendererFeature
{
    [SerializeField]
    private EdgePPPass.Settings _edgeSettings = new EdgePPPass.Settings();
    [SerializeField]
    private Color _edgeColor = Color.black;
    [SerializeField]
    private float _sampleDistance = 1;
    [SerializeField]
    private float _depthSensitivity = 1;
    [SerializeField]
    private float _normalSensitivity = 1;


    private EdgePPPass _blitPass;

    private int _edgeColorPropId = Shader.PropertyToID("_EdgeColor");
    private int _sampleDistancePropId = Shader.PropertyToID("_SampleDistance");
    private int _depthSensitivityPropId = Shader.PropertyToID("_DepthSensitivity");
    private int _normalSensitivityPropId = Shader.PropertyToID("_NormalSensitivity");
    public Color edgeColor { get { return _edgeColor; } set { _edgeColor = value; } }
    public float sampleDistance { get { return _sampleDistance; } set { _sampleDistance = value; } }
    public float depthSensitivity { get { return _depthSensitivity; } set { _depthSensitivity = value; } }
    public float normalSensitivity { get { return _normalSensitivity; } set { _normalSensitivity = value; } }

    public override void Create()
    {
        _blitPass = new EdgePPPass("PostProcessing Edge Detection Depth Normal", _edgeSettings);
    }

    private void UpdateData(Color edgeColor, float sampleDistance, float depthSensitivity, float normalSensitivity)
    {
        _edgeSettings.blitMaterial.SetColor(_edgeColorPropId, edgeColor);
        _edgeSettings.blitMaterial.SetFloat(_sampleDistancePropId, sampleDistance);
        _edgeSettings.blitMaterial.SetFloat(_depthSensitivityPropId, depthSensitivity);
        _edgeSettings.blitMaterial.SetFloat(_normalSensitivityPropId, normalSensitivity);
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        if (_edgeSettings.blitMaterial == null)
        {
            Debug.LogWarningFormat("Missing Blit Material. {0} blit pass will not execute. Check for missing reference in the assigned renderer.", GetType().Name);
            return;
        }
        UpdateData(edgeColor, sampleDistance, depthSensitivity, normalSensitivity);
        renderer.EnqueuePass(_blitPass);
    }
}
