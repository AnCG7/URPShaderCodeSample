Shader "Lakehani/URP/Base/UVCheck"
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
                float2 uv           : TEXCOORD0;//该例子使用了UV1，如果你想看UV2的话改成 TEXCOORD1
            };

            struct Varyings
            {
                float2 uv           : TEXCOORD0;
                float4 positionHCS  : SV_POSITION;
            };

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.uv = IN.uv;
                return OUT;
            }
            //UV 坐标显示为红色和绿色，而额外的蓝色色调应用于0-1范围之外的坐标
            half4 frag(Varyings IN) : SV_Target
            {
                float4 uv = float4(IN.uv.xy,0,0);
                half4 c = frac(uv);
                // any函数 True if any components are non-zero; otherwise, false. 
                //如果参数有任何元素不是0返回true(这个函数的英语翻译过来是真的绕。其实就是如果所有元素都是0，返回false)
                if (any(saturate(uv) - uv))
                    c.b = 0.5;
                return c;
            }
            ENDHLSL
        }
    }
}
