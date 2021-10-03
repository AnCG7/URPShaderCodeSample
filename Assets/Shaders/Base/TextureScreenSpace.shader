Shader "Lakehani/URP/Base/TextureScreenSpace"
{
    Properties
    {
        _BaseMap("BaseMap", 2D) = "white" {}
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" "RenderPipeline"="UniversalRenderPipeline" "Queue"="Geometry"}

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct Attributes
            {
                float4 positionOS   : POSITION;
            };

            struct Varyings
            {
                float4 positionHCS  : SV_POSITION;
                float4 screenPosition : TEXCOORD0;
            };

            TEXTURE2D(_BaseMap);
            SAMPLER(sampler_BaseMap);

            CBUFFER_START(UnityPerMaterial)
            float4 _BaseMap_ST;
            CBUFFER_END

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
                
                OUT.screenPosition = ComputeScreenPos(OUT.positionHCS);
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                //这里除以w是因为需要透视除法
                //顶点变换MVP后到齐次裁剪空间(也是顶点着色器的输出) -> 裁剪 ->透视除法除以w分量 -> NDC(标准化设备坐标) -> 屏幕空间;后4步是流水线做的，所以顶点着色器的输出是齐次裁剪空间
                //而我们算的屏幕空间坐标是自己计算的，所以需要自己完成后3步;ComputeScreenPos并没有透视除法（除以w分量），所以得我们自己除w
                //为什么ComputeScreenPos没有在顶点着色器中除以w分量？在片断着色器中除以w分量的目的是为了得到准确的线性插值，因为齐次坐标是非线性数值，具体的就要要查公式了
                float2 textureCoordinate = IN.screenPosition.xy / IN.screenPosition.w;

                //根据屏幕的宽高比例计算贴图的uv比例。其实不计算aspect也可以，只是图片会根据屏幕比例缩放也就是拉伸和挤压
                float aspect = _ScreenParams.x / _ScreenParams.y;
                textureCoordinate.x = textureCoordinate.x * aspect;

                textureCoordinate = TRANSFORM_TEX(textureCoordinate, _BaseMap);
                return SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, textureCoordinate);
            }
            ENDHLSL
        }
    }
}
