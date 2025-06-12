/*
 * SimpleDecalRendererFeature 负责处理贴花的渲染过程
 * SimpleDecalPrerenderPass 负责处理贴花的预渲染过程，主要是我们要自定义渲染RenderingLayerMask，而不是完全用Unity内置的
 * SimpleDecalRenderPass 负责处理贴花的渲染过程
 */
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Experimental.Rendering;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

[DisallowMultipleRendererFeature("Simple Decal Renderer Feature")]
public class SimpleDecalRendererFeature : ScriptableRendererFeature
{
    private RTHandle _renderingLayersRT;
    private SimpleDecalPrerenderPass _prerenderPass;
    private SimpleDecalRenderPass _decalPass;

    public override void Create()
    {
        _prerenderPass = new SimpleDecalPrerenderPass();
        _decalPass = new SimpleDecalRenderPass();
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        renderer.EnqueuePass(_prerenderPass);
        renderer.EnqueuePass(_decalPass);
    }
    public override void SetupRenderPasses(ScriptableRenderer renderer, in RenderingData renderingData)
    {
        var renderingLayersTextureName = "_SimpleDecalRenderingLayersTexture";
        RenderTextureDescriptor cameraTargetDescriptor = renderingData.cameraData.cameraTargetDescriptor;
        var renderingLayersDescriptor = cameraTargetDescriptor;
        renderingLayersDescriptor.depthBufferBits = 0;
        renderingLayersDescriptor.msaaSamples = 1;
        renderingLayersDescriptor.graphicsFormat = GraphicsFormat.R8_UNorm;
        RenderingUtils.ReAllocateIfNeeded(ref _renderingLayersRT, renderingLayersDescriptor, FilterMode.Point, 
            TextureWrapMode.Clamp, name: renderingLayersTextureName);
        _prerenderPass.Setup(renderer, renderingData,_renderingLayersRT);
    }
    //这是个内置的方法，我们可以通过重写这个方法来告诉URP我们需要使用RenderingLayer来做对渲染层的过滤，但是现在他是internal,为了学习，我没有使用这个方法，而是自己实现了一个Buffer
    //看SimpleDecalPrerenderPass
    // public override bool RequireRenderingLayers(bool isDeferred, bool needsGBufferAccurateNormals, out object atEvent, object maskSize)
    // {
    //     atEvent = RenderingLayerUtils.Event.DepthNormalPrePass;
    //     maskSize = RenderingLayerUtils.MaskSize.Bits8;
    //     return true;
    // }
    protected override void Dispose(bool disposing)
    {
        if (_renderingLayersRT != null)
        {
            _renderingLayersRT.Release();
            _renderingLayersRT = null;
        }
        if (_prerenderPass!= null)
        {
            _prerenderPass.Dispose();
            _prerenderPass = null;
        }
        SimpleDecalDataManager.Clear();
    }
}

public class SimpleDecalPrerenderPass : ScriptableRenderPass
{
    private RTHandle _renderingLayersRT;
    private Material _renderMaterial;
    private List<ShaderTagId> _shaderTags = new List<ShaderTagId>(1);
    private FilteringSettings _filteringSettings;
    #region unity内置的RenderingLayer相关，我们并不是完全重写，我们同样需要使用RenderingLayerMask来做对渲染层的裁剪
    private readonly int _renderingLayerMaxIntShaderID = Shader.PropertyToID("_RenderingLayerMaxInt");
    private readonly int _renderingLayerRcpMaxIntShaderID = Shader.PropertyToID("_RenderingLayerRcpMaxInt");
    #endregion

    public SimpleDecalPrerenderPass()
    {
        renderPassEvent = RenderPassEvent.AfterRenderingPrePasses;
        _renderMaterial = CoreUtils.CreateEngineMaterial(Shader.Find("Lakehani/URP/Effect/SimpleDecalPreRender"));
        _shaderTags.Add(new ShaderTagId("UniversalForward"));//借用内置Tag
        _filteringSettings = new FilteringSettings(RenderQueueRange.opaque,-1);
    }
    
    public void Dispose()
    {
        if (_renderMaterial != null)
        {
            CoreUtils.Destroy(_renderMaterial);
            _renderMaterial = null;
        }
    }

    public void Setup(ScriptableRenderer renderer, RenderingData renderingData,RTHandle renderingLayersRT)
    {
        _renderingLayersRT = renderingLayersRT;
    }
    
    public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
    {
        if (_renderingLayersRT != null)
        {
            ConfigureTarget(_renderingLayersRT);
        }
        ConfigureClear(ClearFlag.All, Color.black);
    }

    public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
    {
        var cmd = CommandBufferPool.Get("Simple Decal Prerender");
        cmd.Clear();
        if (_renderingLayersRT == null)
        {
            return;
        }
        cmd.SetGlobalTexture(_renderingLayersRT.name, _renderingLayersRT.nameID);
        SetupProperties(cmd,8);
        context.ExecuteCommandBuffer(cmd);
        
        
        var sortFlags = renderingData.cameraData.defaultOpaqueSortFlags;
        // 绘制不透明物体
        var drawSettings = CreateDrawingSettings(_shaderTags,ref renderingData, sortFlags);
        drawSettings.overrideMaterial = _renderMaterial;
        // drawSettings.perObjectData = PerObjectData.None;
        //_filteringSettings可以自定义LayerMask和RenderingLayerMask,这里不再优化，直接走默认
        //_filteringSettings.layerMask,_filteringSettings.renderingLayerMask
        context.DrawRenderers(renderingData.cullResults, ref drawSettings, ref _filteringSettings);
        CommandBufferPool.Release(cmd);
    }
    
    //参考 RenderingLayerUtils.SetupProperties(cmd, renderingLayerMaskSize);这个是internal函数，无法直接调用，这里仿造他的实现，来设置RenderingLayer相关的属性
    private void SetupProperties(CommandBuffer cmd, int bits)
    {
        uint maxInt = bits != 32 ? (1u << bits) - 1u : uint.MaxValue;
        float rcpMaxInt = Unity.Mathematics.math.rcp(maxInt);
        cmd.SetGlobalInt(_renderingLayerMaxIntShaderID, (int)maxInt);
        cmd.SetGlobalFloat(_renderingLayerRcpMaxIntShaderID, rcpMaxInt);
    }
}


public class SimpleDecalRenderPass : ScriptableRenderPass
{
    private List<SimpleDecalDataManager.DecalData> _decalDataList = new List<SimpleDecalDataManager.DecalData>();
    private List<ShaderTagId> _shaderTags = new List<ShaderTagId>(1);
    private FilteringSettings _filteringSettings;
    public SimpleDecalRenderPass()
    {
        renderPassEvent = RenderPassEvent.AfterRenderingSkybox;
        // var scriptableRenderPassInput = ScriptableRenderPassInput.Depth; // 请求深度
        var scriptableRenderPassInput = ScriptableRenderPassInput.Depth | ScriptableRenderPassInput.Normal; //请求深度和法线
        ConfigureInput(scriptableRenderPassInput);
        _shaderTags.Add(new ShaderTagId("UniversalForward"));//借用内置Tag
        _filteringSettings = new FilteringSettings(RenderQueueRange.opaque, -1);
    }
    
    public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
    {
        var cmd = CommandBufferPool.Get("Simple Decal Render");
        cmd.Clear();
        // 收集所有激活的贴花 ,绘制每个贴花,在decalDataMap下的都是激活的贴花
        // var decalMap = SimpleDecalDataManager.decalDataMap;
        // if (decalMap == null) return;
        //做一下剔除要不贴花数量过多时排序耗时，这里只是示例，因为优化方案是一个大话题
        SimpleDecalDataManager.GetCullingAndSortedDecalList(ref _decalDataList);
        foreach (var decalData in _decalDataList)
        {
            SimpleDecalDataManager.UpdateMaterialProperty(decalData);
            //可以通过配套使用DrawMeshInstanced来优化
            //也可以参考Unity自己的贴花DecalDrawSystem中的Graphics.DrawMesh和context.DrawRenderers配合绘制
            cmd.DrawMesh(
                decalData.projectorMesh,//这里通过绘制一个cube和投影的box一致来覆盖渲染的区域，而不是一个全屏的quad，因为全屏的quad渲染时屏占比很多，但是其实我们其实只是要渲染一部分
                decalData.projectorMeshMatrix,
                decalData.material,
                0,
                0,
                decalData.materialPropertyBlock
            );
        }
        context.ExecuteCommandBuffer(cmd);
        CommandBufferPool.Release(cmd);   
    }
}
