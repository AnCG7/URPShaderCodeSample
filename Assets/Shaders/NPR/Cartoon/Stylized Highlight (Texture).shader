//根据Blinn高光的半角向量，在切线空间中采样纹理，将纹理映射到高光范围
//也可以使用公式变换高光，使高光可以有：平移，旋转，缩放，分割，方块化 的效果，具体参考Shader: Stylized Highlight Transform
//本质都是变换半角向量，所以这个2个shader可以结合使用

//参考：
//https://zhuanlan.zhihu.com/p/640258070

Shader "Lakehani/URP/NPR/Cartoon/Stylized Highlight Texture"
{

    Properties
    {
        _SpecularShapeMap("Specular Shape Map", 2D) = "white" {}
        _SpecularColor ("Specular Color", Color) = (1,1,1,1)
       	_SpecularScale ("Specular Scale", Float) = 1
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
                float4 tangentOS     : TANGENT;
            };

            struct Varyings
            {
                float4 positionHCS  : SV_POSITION;
                float3 normalTS : TEXCOORD0;
                float3 viewTS : TEXCOORD1;
                float3 lightDirTS : TEXCOORD2;
            };


            CBUFFER_START(UnityPerMaterial)
            half4 _SpecularColor;
            half _SpecularScale;
            CBUFFER_END
            TEXTURE2D(_SpecularShapeMap);
            SAMPLER(sampler_SpecularShapeMap);


            Varyings vert(Attributes IN)
            {
                Varyings OUT;

                float3 positionWS = TransformObjectToWorld(IN.positionOS.xyz);
                OUT.positionHCS = TransformWorldToHClip(positionWS);

                VertexNormalInputs normalInput = GetVertexNormalInputs(IN.normalOS, IN.tangentOS);
                float3x3 TBNWorld = float3x3(normalInput.tangentWS.xyz, normalInput.bitangentWS.xyz, normalInput.normalWS.xyz);
                OUT.normalTS = TransformWorldToTangent(normalInput.normalWS,TBNWorld);
                OUT.viewTS = TransformWorldToTangent(GetWorldSpaceViewDir(positionWS),TBNWorld);
                OUT.lightDirTS = TransformWorldToTangent(GetMainLight().direction,TBNWorld);

                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                half3 normalTS = normalize(IN.normalTS);
				half3 lightDirTS = normalize(IN.lightDirTS);
				half3 viewTS = normalize(IN.viewTS);
				half3 halfDirTS = normalize(viewTS + lightDirTS);

                //正常的Blinn高光用来对比映射点是否正常
                Light light = GetMainLight();
                half3 lightColor = light.color * light.distanceAttenuation;
                //half smoothnessFactor = 0.8;
                //half smoothness = exp2(10 * smoothnessFactor + 1);
                //half NdotH = saturate(dot(normalTS, halfDirTS));
                //half modifier = pow(NdotH, smoothness);
                //half4 specularColor = half4(1,0,0,1) * modifier;

                //在切线空间TBN中，归一化后的xy正好可以转换为uv，但是取值范围不一样，我们需要冲[-1,1]转换为[0,1],并颠倒轴向以适应uv的方向
                //反转轴向
                half2 flip =  halfDirTS.xy * -1;
                //调整向量大小，其实等于再缩放uv,并防止除0
                half2 scale = flip * 1/max(0.01,_SpecularScale);
                //将范围映射到[0,1]
                half2 uv = scale + half2(1,1) * 0.5;
                half4 shape = SAMPLE_TEXTURE2D(_SpecularShapeMap, sampler_SpecularShapeMap,uv);

                //和上面注释一对，用来对比映射点是否正常
                //half4 totalColor = specularColor + shape;
                half4 totalColor = shape * _SpecularColor * half4(lightColor.rgb,1);
                return totalColor;
            }

            ENDHLSL
        }
    }
}
