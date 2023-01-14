//其实就是Blit，屏幕后期处理，只是换了种写法，Blit前组装需要的数据，画了很大的篇幅
//Blit参考 https://github.com/Unity-Technologies/UniversalRenderingExamples 的 DrawFullscreenFeature、DrawFullscreenPass和编辑器代码DrawFullScreenFeatureDrawer
//更多参考Unity自带的RenderObjects.cs
//对于后处理来说这个部分代码基本都一样，可以在这个基础上修改

using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class EdgePPPass : ScriptableRenderPass
{
    public enum BufferType
    {
        CameraColor,
        Custom
    }

    [System.Serializable]
    public class Settings
    {
        public RenderPassEvent renderPassEvent = RenderPassEvent.AfterRenderingOpaques;
        public bool enableNormalTexture;
        public Material blitMaterial = null;
        public int blitMaterialPassIndex = -1;
    }

    public FilterMode filterMode { get; set; }
    private Settings _settings;
    private RenderTargetIdentifier _source;
    private RenderTargetIdentifier _temporaryRT;
    private int _temporaryRTId = Shader.PropertyToID("_OutlineTempRT");
    private string _profilerTag;

    public EdgePPPass(string tag, Settings settings)
    {
        _profilerTag = tag;
        _settings = settings;
        renderPassEvent = _settings.renderPassEvent;
        if (_settings.enableNormalTexture)
        {
            ConfigureInput(ScriptableRenderPassInput.Normal);
        }
    }



    public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
    {
        RenderTextureDescriptor blitTargetDescriptor = renderingData.cameraData.cameraTargetDescriptor;
        blitTargetDescriptor.depthBufferBits = 0;

        var renderer = renderingData.cameraData.renderer;
        _source = renderer.cameraColorTarget;
        cmd.GetTemporaryRT(_temporaryRTId, blitTargetDescriptor, filterMode);
        _temporaryRT = new RenderTargetIdentifier(_temporaryRTId);
    }

    public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
    {
        CommandBuffer cmd = CommandBufferPool.Get(_profilerTag);
        Blit(cmd, _source, _temporaryRT, _settings.blitMaterial, _settings.blitMaterialPassIndex);
        Blit(cmd, _temporaryRT, _source);

        context.ExecuteCommandBuffer(cmd);
        CommandBufferPool.Release(cmd);
    }

    
    public override void FrameCleanup(CommandBuffer cmd)
    {
        if (_temporaryRTId != -1)
            cmd.ReleaseTemporaryRT(_temporaryRTId);
    }
}
