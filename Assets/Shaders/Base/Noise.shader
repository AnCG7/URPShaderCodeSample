Shader "Lakehani/URP/Base/Noise"
{
    Properties
    {
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
                float2 uv:TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionHCS  : SV_POSITION;
                float2 uv:TEXCOORD0;
            };

            float RandomNoise(float2 seed)//低成本Noise函数,一个简单的伪随机
            {
                return frac(sin(dot(seed, float2(12.9898, 78.233)))*43758.5453);
            }

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                float3 positionWS = TransformObjectToWorld(IN.positionOS.xyz);
                OUT.positionHCS = TransformWorldToHClip(positionWS);
                OUT.uv = IN.uv;
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                //噪波一般通过采样单通道的由其他软件生成的噪波图实现
                //常见噪波类型记录一下 Perlin Noise、Simplex Noise、Wavelet Noise、Value Noise、Worley Noise
                //这里不是展示算法库，根据以上算法的图形对比，会比较好理解。 
                //ShaderGraph的生成代码中有现成的算法可以使用
                //因为程序化生成上述噪波计算量过大，所以这里使用一个简单的伪随机来程序化生成噪点
                //RandomNoise(floor(IN.uv * _BlockSize));可以生成块状的随机区域
                float n = RandomNoise(IN.uv);
                return  half4(n,n,n,n);
            }

            ENDHLSL
        }
    }
}
