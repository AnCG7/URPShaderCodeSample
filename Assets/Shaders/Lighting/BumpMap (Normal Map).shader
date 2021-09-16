Shader "Lakehani/URP/Lighting/BumpMap"
{
    Properties
    {
        _BumpTexture("Normal Texture", 2D) = "white" {}
        _Threshold("Threshold",float) = 1.0
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
                float3 normalOS      : NORMAL;
                float4 tangentOS     : TANGENT;
                float2 uv:TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionHCS  : SV_POSITION;
                float2 uv:TEXCOORD0;
                float3 normalWS : TEXCOORD1;    //注意这里其实更改为float4
                float3 tangentWS : TEXCOORD2;   //然后把view视角向量的xyz的值放入normalWS、tangentWS、bitangentWS 的w分量
                float3 bitangentWS : TEXCOORD3; //来节省TEXCOORD的数量
                float3 viewWS : TEXCOORD4; 
                
            };

            CBUFFER_START(UnityPerMaterial)
            float4 _BumpTexture_ST;
            float _Threshold;
            CBUFFER_END

            TEXTURE2D(_BumpTexture);SAMPLER(sampler_BumpTexture);

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                float3 positionWS = TransformObjectToWorld(IN.positionOS.xyz);
                OUT.positionHCS = TransformWorldToHClip(positionWS);

                OUT.uv = TRANSFORM_TEX(IN.uv, _BumpTexture);

                OUT.viewWS = GetWorldSpaceViewDir(positionWS);

                VertexNormalInputs normalInput = GetVertexNormalInputs(IN.normalOS, IN.tangentOS);
                OUT.normalWS = normalInput.normalWS;
                OUT.tangentWS = normalInput.tangentWS;
                OUT.bitangentWS = normalInput.bitangentWS;

                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                //也可以直接使用宏SampleNormal，但是需要自己加宏定义，具体见 SurfaceInput.hlsl 
                half4 n = SAMPLE_TEXTURE2D(_BumpTexture, sampler_BumpTexture, IN.uv);
                //注意取出的法线贴图是在切线空间的
                half3 normalTS = UnpackNormalScale(n, _Threshold);
                //把取出来的法线贴图转换到世界空间
                half3 normalWS = TransformTangentToWorld(normalTS,half3x3(IN.tangentWS.xyz, IN.bitangentWS.xyz, IN.normalWS.xyz));
                normalWS = normalize(normalWS);
                half3 viewWS = SafeNormalize(IN.viewWS);
                //注意这里为 lambert（漫反射）+ BlinnPhong（高光）因为不加光照看不出来法线贴图的作用,
                //对于法线贴图的关键点是如何正确取出贴图中的法线数据，以下代码用于演示效果。
                //具体的光照部分，请看光照对比中的shader
                Light light = GetMainLight();
                half3 lightColor = light.color * light.distanceAttenuation;
                half smoothness = exp2(10 * 0.5 + 1);

                half3 ambientColor = unity_AmbientSky.rgb;
                half3 specularColor = LightingSpecular(lightColor, light.direction, normalWS, viewWS, half4(1,1,1,1), smoothness);
                half3 diffuseColor=LightingLambert(lightColor,light.direction,normalWS);
                half3 totalColor= diffuseColor + specularColor + ambientColor;

                return half4(totalColor.rgb,1);
            }

            ENDHLSL
        }
    }
}
