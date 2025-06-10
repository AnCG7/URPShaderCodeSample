//这个Feature是我用来调试JFA的因为URP不支持Build-in中的OnRenderImage，所以只能自己写一个Feature来实现JFA，Debug来观察FrameDebugger的效果
//具体内容看SDFJFACS.compute
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class JFARendererDebugFeature : ScriptableRendererFeature
{
    public enum ColorChannelEnum
    {
        R = 0,
        G = 1, 
        B = 2,
        A = 3,
    }
    class JFARendererDebugPass : ScriptableRenderPass
    {
        private ComputeShader _jfaShader;
        private Texture2D _sourceTexture;
        private int _initSeedKernel;
        private int _jfaKernel;
        private int _fillDistanceTransformKernel;
        private CommandBuffer _commandBuffer;

        private int _tmp1Id;
        private int _tmp2Id;
        private int _textureId;
        private int _sourceId;
        private int _widthId;
        private int _heightId;
        private int _stepId;
        private int _resultId;
        private int _readChannelId;
        private int _writeChannelId;

        private ColorChannelEnum _srcChannel = ColorChannelEnum.A;
        private ColorChannelEnum _targetChannel = ColorChannelEnum.A;
        public JFARendererDebugPass(ComputeShader jfaShader, Texture2D sourceTexture)
        {
            this._jfaShader = jfaShader;
            this._sourceTexture = sourceTexture;
            _commandBuffer = CommandBufferPool.Get("JFARendererFeature");

            _initSeedKernel = jfaShader.FindKernel("InitSeed");
            _jfaKernel = jfaShader.FindKernel("JFA");
            _fillDistanceTransformKernel = jfaShader.FindKernel("FillDistanceTransform");

            _tmp1Id = Shader.PropertyToID("JFA Tmp1");
            _tmp2Id = Shader.PropertyToID("JFA Tmp2");
            _textureId = Shader.PropertyToID("_Texture");
            _sourceId = Shader.PropertyToID("Source");
            _widthId = Shader.PropertyToID("Width");
            _heightId = Shader.PropertyToID("Height");
            _stepId = Shader.PropertyToID("Step");
            _resultId = Shader.PropertyToID("Result");
            _readChannelId = Shader.PropertyToID("ReadChannel");
            _writeChannelId = Shader.PropertyToID("WriteChannel");
        }

        public void Setup(ColorChannelEnum srcChannel, ColorChannelEnum targetChannel)
        {
            _srcChannel = srcChannel;
            _targetChannel = targetChannel;
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            if (_jfaShader == null || _sourceTexture == null)
            {
                return;
            }

            RenderTextureDescriptor rtd = new RenderTextureDescriptor(_sourceTexture.width, _sourceTexture.height, RenderTextureFormat.ARGBFloat, 0);
            rtd.enableRandomWrite = true;

            _commandBuffer.GetTemporaryRT(_tmp1Id, rtd);
            _commandBuffer.GetTemporaryRT(_tmp2Id, rtd);

            RenderTargetIdentifier textureRTI = new RenderTargetIdentifier(_sourceTexture);
            RenderTargetIdentifier tmp1RTI = new RenderTargetIdentifier(_tmp1Id);
            RenderTargetIdentifier tmp2RTI = new RenderTargetIdentifier(_tmp2Id);

            int threadGroupsX = Mathf.CeilToInt(_sourceTexture.width / 8.0f);
            int threadGroupsY = Mathf.CeilToInt(_sourceTexture.height / 8.0f);
            
            _commandBuffer.SetComputeIntParam(_jfaShader, _readChannelId, (int)_srcChannel);
            _commandBuffer.SetComputeIntParam(_jfaShader, _writeChannelId, (int)_targetChannel);
            
            // Init Seed
            _commandBuffer.SetComputeTextureParam(_jfaShader, _initSeedKernel, _textureId, textureRTI);
            _commandBuffer.SetComputeTextureParam(_jfaShader, _initSeedKernel, _sourceId, tmp1RTI);
            _commandBuffer.SetComputeIntParam(_jfaShader, _widthId, _sourceTexture.width);
            _commandBuffer.SetComputeIntParam(_jfaShader, _heightId, _sourceTexture.height);
            _commandBuffer.DispatchCompute(_jfaShader, _initSeedKernel, threadGroupsX, threadGroupsY, 1);

            // JFA
            int stepAmount = (int)Mathf.Log(Mathf.Max(_sourceTexture.width, _sourceTexture.height), 2);
            for (int i = 0; i < stepAmount; i++)
            {
                int step = (int)Mathf.Pow(2, stepAmount - i - 1);
                _commandBuffer.SetComputeIntParam(_jfaShader, _stepId, step);
                _commandBuffer.SetComputeTextureParam(_jfaShader, _jfaKernel, _sourceId, tmp1RTI);
                _commandBuffer.SetComputeTextureParam(_jfaShader, _jfaKernel, _resultId, tmp2RTI);
                _commandBuffer.DispatchCompute(_jfaShader, _jfaKernel, threadGroupsX, threadGroupsY, 1);
                _commandBuffer.CopyTexture(tmp2RTI, tmp1RTI);
            }

            _commandBuffer.SetComputeTextureParam(_jfaShader, _fillDistanceTransformKernel, _sourceId, tmp1RTI);
            _commandBuffer.SetComputeTextureParam(_jfaShader, _fillDistanceTransformKernel, _resultId, tmp2RTI);
            _commandBuffer.DispatchCompute(_jfaShader, _fillDistanceTransformKernel, threadGroupsX, threadGroupsY, 1);

            // 将 JFA 结果应用到最终渲染
            _commandBuffer.Blit(tmp2RTI, renderingData.cameraData.renderer.cameraColorTargetHandle);

            context.ExecuteCommandBuffer(_commandBuffer);

            _commandBuffer.ReleaseTemporaryRT(_tmp1Id);
            _commandBuffer.ReleaseTemporaryRT(_tmp2Id);
            _commandBuffer.Clear();
        }
    }

    public Texture2D texture;
    public ComputeShader JFAShader;
    public ColorChannelEnum srcChannel = ColorChannelEnum.A;
    public ColorChannelEnum targetChannel = ColorChannelEnum.R;
    
    private JFARendererDebugPass _jfaRendererDebugPass;

    public override void Create()
    {
        _jfaRendererDebugPass = new JFARendererDebugPass(JFAShader, texture);
        _jfaRendererDebugPass.renderPassEvent = RenderPassEvent.AfterRenderingPostProcessing;
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        if (JFAShader == null || texture == null)
        {
            return;
        }
        _jfaRendererDebugPass.Setup(srcChannel,targetChannel);
        renderer.EnqueuePass(_jfaRendererDebugPass);
    }
}
