Shader "Lakehani/URP/Lighting/BackLight"
{
    Properties
    {
        _Distortion ("Distortion", float) = 0.5
        _Power ("Power",  float) = 0.5
        _Scale ("Scale",  float) = 0.5
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
                float3 viewWS : TEXCOORD1;
            };

            CBUFFER_START(UnityPerMaterial)
            half _Distortion;
            half _Power;
            half _Scale;
            CBUFFER_END

            //也可以当作一透射效果
            half3 LightingBackLight(half3 lightDirWS, half3 normalWS, half3 viewDirWS,half distortion,half power, half scale)
            {
                half3 N_Shift = -normalize(normalWS * distortion + lightDirWS);//沿着光线方向上偏移法线，最后在取反
                half backLight = saturate(pow(saturate( dot(N_Shift,viewDirWS)) , power) * scale);
                return backLight;
            }

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                float3 positionWS = TransformObjectToWorld(IN.positionOS.xyz);
                OUT.positionHCS = TransformWorldToHClip(positionWS);
                OUT.normalWS =TransformObjectToWorldNormal(IN.normalOS);
                OUT.viewWS = GetWorldSpaceViewDir(positionWS);

                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                Light light = GetMainLight();
                half3 lightColor = light.color * light.distanceAttenuation;

                half3 backLightColor= LightingBackLight(light.direction, normalize(IN.normalWS), SafeNormalize(IN.viewWS), _Distortion, _Power,_Scale)* lightColor;

                half4 totalColor=half4(backLightColor.rgb,1);

                return totalColor;

            }



            ENDHLSL
        }
    }
}
