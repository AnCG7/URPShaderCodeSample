//参考
//https://zznewclear13.github.io/posts/calculate-signed-distance-field-using-compute-shader/
//https://github.com/alpacasking/JumpFloodingAlgorithm
//https://blog.demofox.org/2016/02/29/fast-voronoi-diagrams-and-distance-dield-textures-on-the-gpu-with-the-jump-flooding-algorithm/

using UnityEditor;
using UnityEngine;
using UnityEngine.Rendering;

namespace SDFGenerator2D
{
    public class SDFJFA
	{
		private ComputeShader _jfaShader;

		private int _initSeedKernel;
		private int _jfaKernel;
		private int _fillDistanceTransformKernel; 
        private CommandBuffer _commandBuffer;
        private RenderTextureDescriptor _renderTextureDesc;
        private RenderTargetIdentifier _tmp1RTI;
        private RenderTargetIdentifier _tmp2RTI;

        
        private int _tmp1ShaderId = Shader.PropertyToID("JFA Tmp1");
        private int _tmp2ShaderId = Shader.PropertyToID("JFA Tmp2");
        private int _textureShaderId = Shader.PropertyToID("_Texture");
        private int _sourceShaderId = Shader.PropertyToID("Source");
        private int _widthShaderId = Shader.PropertyToID("Width");
        private int _heightShaderId = Shader.PropertyToID("Height");
        private int _stepShaderId = Shader.PropertyToID("Step");
        private int _resultShaderId = Shader.PropertyToID("Result");
        private int _readChannelShaderId = Shader.PropertyToID("ReadChannel");
        private int _writeChannelShaderId = Shader.PropertyToID("WriteChannel");
       
        public SDFJFA()
		{
            _jfaShader = AssetDatabase.LoadAssetAtPath<ComputeShader>("Assets/Editor/SDFGeneratorEditor/SDFJFACS.compute");
            _initSeedKernel = _jfaShader.FindKernel("InitSeed");
			_jfaKernel = _jfaShader.FindKernel("JFA");
			_fillDistanceTransformKernel = _jfaShader.FindKernel("FillDistanceTransform");
            _commandBuffer = new CommandBuffer();
            _renderTextureDesc = new RenderTextureDescriptor(0, 0, RenderTextureFormat.ARGBFloat, 0);
            _renderTextureDesc.enableRandomWrite = true;
            _tmp1RTI = new RenderTargetIdentifier(_tmp1ShaderId);
            _tmp2RTI = new RenderTargetIdentifier(_tmp2ShaderId);
        }
        private RenderTexture _resultTexture;
        private Texture2D _targetTexture;
        private EColorChannel _srcChanel;
        private EColorChannel _targetChannel;
        public void Generate(Texture2D srcTexture, Texture2D targetTexture, EColorChannel srcChanel = EColorChannel.A, EColorChannel targetChannel = EColorChannel.A)
		{
            _targetTexture = targetTexture;
            _srcChanel = srcChanel;
            _targetChannel = targetChannel;
            _resultTexture = GenerateJFA(srcTexture);
            SDFUtils.WriteTexture(_resultTexture,targetTexture, targetChannel,targetChannel);
        }
        
        private RenderTexture GenerateJFA(Texture2D srcTexture)
		{
            _renderTextureDesc.width = srcTexture.width;
            _renderTextureDesc.height = srcTexture.height;

            RenderTexture resultRT = RenderTexture.GetTemporary(_renderTextureDesc);
            _commandBuffer.GetTemporaryRT(_tmp1ShaderId, _renderTextureDesc);
            _commandBuffer.GetTemporaryRT(_tmp2ShaderId, _renderTextureDesc);

            RenderTargetIdentifier textureRTI = new RenderTargetIdentifier(srcTexture);

            int threadGroupsX = Mathf.CeilToInt(srcTexture.width / 8.0f);
            int threadGroupsY = Mathf.CeilToInt(srcTexture.height / 8.0f);
            
            int srcChannel = ColorChannelToShaderChannel(_srcChanel);
            int targetChannel = ColorChannelToShaderChannel(_targetChannel);
            _commandBuffer.SetComputeIntParam(_jfaShader, _readChannelShaderId, srcChannel);
            _commandBuffer.SetComputeIntParam(_jfaShader, _writeChannelShaderId, targetChannel);
            // Init Seed
            _commandBuffer.SetComputeTextureParam(_jfaShader, _initSeedKernel, _textureShaderId, textureRTI);
            _commandBuffer.SetComputeTextureParam(_jfaShader, _initSeedKernel, _sourceShaderId, _tmp1RTI);
            _commandBuffer.SetComputeIntParam(_jfaShader, _widthShaderId, srcTexture.width);
            _commandBuffer.SetComputeIntParam(_jfaShader, _heightShaderId, srcTexture.height);
            _commandBuffer.DispatchCompute(_jfaShader, _initSeedKernel, threadGroupsX, threadGroupsY, 1);

            // JFA
            // 在 n x n 大小的纹理上使用 Jump Flooding Algorithm 计算距离场时，理论上最多需要 log2(n) 次迭代，因为每次迭代步长减半
            int stepAmount = (int)Mathf.Log(Mathf.Max(srcTexture.width, srcTexture.height), 2);
            for (int i = 0; i < stepAmount; i++)
            {
                int step = (int)Mathf.Pow(2, stepAmount - i - 1);
                _commandBuffer.SetComputeIntParam(_jfaShader, _stepShaderId, step);
                _commandBuffer.SetComputeTextureParam(_jfaShader, _jfaKernel, _sourceShaderId, _tmp1RTI);
                _commandBuffer.SetComputeTextureParam(_jfaShader, _jfaKernel, _resultShaderId, _tmp2RTI);
                _commandBuffer.DispatchCompute(_jfaShader, _jfaKernel, threadGroupsX, threadGroupsY, 1);
                _commandBuffer.CopyTexture(_tmp2RTI, _tmp1RTI);
            }
            _commandBuffer.SetComputeTextureParam(_jfaShader, _fillDistanceTransformKernel, _sourceShaderId, _tmp1RTI);
            _commandBuffer.SetComputeTextureParam(_jfaShader, _fillDistanceTransformKernel, _resultShaderId, _tmp2RTI);
            _commandBuffer.DispatchCompute(_jfaShader, _fillDistanceTransformKernel, threadGroupsX, threadGroupsY, 1);
            _commandBuffer.Blit(_tmp2RTI, resultRT);

            Graphics.ExecuteCommandBuffer(_commandBuffer);
            
            _commandBuffer.ReleaseTemporaryRT(_tmp1ShaderId);
            _commandBuffer.ReleaseTemporaryRT(_tmp2ShaderId);
            _commandBuffer.Clear();
            return resultRT;
        }
		private int ColorChannelToShaderChannel(EColorChannel channel)
		{
			switch (channel)
			{
				case EColorChannel.R:
					return 0;
				case EColorChannel.G:
					return 1;
				case EColorChannel.B:
					return 2;
				case EColorChannel.A:
					return 3;
				default:
					return 0;
			}
		}
	}
}
