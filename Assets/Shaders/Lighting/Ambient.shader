/*
可以在Windows -> Lighting -> Environment -> Environment Lighting 中调节
*/
Shader "Lakehani/URP/Lighting/Ambient"
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
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            struct Attributes
            {
                float4 positionOS   : POSITION;
                float3 normalOS : NORMAL;
            };

            struct Varyings
            {
                float4 positionHCS  : SV_POSITION;
                float3 normalWS : TEXCOORD0;
            };

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                float3 positionWS = TransformObjectToWorld(IN.positionOS.xyz);
                OUT.positionHCS = TransformWorldToHClip(positionWS);
                OUT.normalWS=TransformObjectToWorldNormal(IN.normalOS);
                return OUT;
            }

            half4 CalculateGradientAmbient(float3 normalWS)
            {
                half4 ambientColor = lerp(unity_AmbientEquator,unity_AmbientSky,saturate(normalWS.y));
                ambientColor = lerp(ambientColor,unity_AmbientGround,saturate(-normalWS.y));
                return ambientColor;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                half3 normalWS = normalize(IN.normalWS);
                //real4 unity_AmbientSky、unity_AmbientEquator、unity_AmbientGround 被定义在 UnityInput.hlsl
                //Unity把环境光的计算放到了球谐光照中也就是 OUTPUT_SH 宏定义 详细见 Lighting.hlsl
                //另一种写法 half3 ambientColor = half3(unity_SHAr.w, unity_SHAg.w, unity_SHAb.w);//该写可以正常使用Sky或者Color，Gradient模式无效，而且在bake后再调节颜色无效
                //如果想要所有环境光模式都有效可以直接使用 Lighting.hlsl中的 SampleSHVertex 或者 SampleSHPixel函数，也就是球谐光照，但是我没有找到相关的计算过程，可能是Unity传递过来的参数中已经计算过了。
                //注意 UNITY_LIGHTMODEL_AMBIENT宏 已经被标记为 过时的
                //所以自己搞了Gradient一个作为一个简单的示例。
                //half4 ambientColor= CalculateGradientAmbient(normalWS);

                half4 ambientColor = unity_AmbientSky;


                half4 totlaColor = half4(ambientColor.rgb,1);
                return totlaColor;
            }

            ENDHLSL
        }
    }
}
