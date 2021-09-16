/* URP中 unity 的PBR的实现公式
可以参考Lighting.hlsl中的 UniversalFragmentPBR
URP中Unity使用了自己改造后的公式来实现
cook-torrance镜面反射方程 = DFG/4(wo ⋅ n)(wi ⋅ n)
一般的其中分子的
*D项(NDF) 法线分布函数：估算在受到表面粗糙度的影响下，法线方向与中间向量一致的微平面的数量。这是用来估算微平面的主要函数。
*G项 几何函数：描述了微平面自成阴影的属性。当一个平面相对比较粗糙的时候，平面表面上的微平面有可能挡住其他的微平面从而减少表面所反射的光线。
*F项 菲涅尔方程：菲涅尔方程描述的是在不同的表面角下表面所反射的光线所占的比率(不同介质之间折射和反射的比率)。
*每一项都有很多公式可以替代

其中分子 G/4(wo ⋅ n)(wi ⋅ n) 又常作为可见项V (Visibility)
所以 镜面反射方程 = DFV 
*Unity在 Lighting.hlsl 也有写到如下参考内容 https://community.arm.com/events/1155
或者直接看 https://community.arm.com/cfs-file/__key/communityserver-blogs-components-weblogfiles/00-00-00-20-66/siggraph2015_2D00_mmg_2D00_renaldas_2D00_slides.pdf
D = roughness^2 / PI*( NoH^2 * (roughness^2 - 1) + 1 )^2 //Trowbridge-Reitz GGX
F = specColor / LoH //并没有直接使用常见的Fresnel Schlick近似
V = 1/(LoH)^2 * (1-roughness^2)+roughness^2 * 4

但是对 V*F 的公式再次进行近似
V * F = (1.0 / ( LoH^2 * (roughness + 0.5) ))*specColor

最终的 BRDFspec = specColor * (roughness^2 / (4.0 * PI * ( NoH^2 * (roughness^2 - 1) + 1 )^2 * LoH^2 * (roughness + 0.5)))

因为有高光工作流和金属工作流 具体区别可以参考 Lighting.hlsl InitializeBRDFData 中的 _SPECULAR_SETUP 宏
以下代码是金属工作流中的PBR公式实现
*/

Shader "Lakehani/URP/Lighting/UnityPBRInURP"
{
    Properties
    {
        _Albedo ("Albedo", Color) = (1,1,1,1)
        _Metallic ("Metallic",  Range(0,1)) = 0.5
        _Roughness  ("Roughness",Range(0,1)) = 0.5
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" "RenderPipeline"="UniversalRenderPipeline"}

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
                float3 viewWS : TEXCOORD2;
            };

            CBUFFER_START(UnityPerMaterial)
            half3 _Albedo;
            half _Metallic;
            half _Roughness;
            CBUFFER_END

            //NDF D项 Trowbridge-Reitz GGX
            half D_GGX_TR(half3 N, half3 H, half roughness)
            {
                half a = roughness;
                half a2     = a * a;
                half NdotH  = max(dot(N, H), 0.0);
                half NdotH2 = NdotH*NdotH;

                half nom    = a2;
                half denom  = (NdotH2 * (a2 - 1.0) + 1.0);
                denom        = PI * denom * denom;

                return nom / denom;
            }

           //Unity自己近似实现的 V*F 项
           //V * F = (1.0 / ( LoH^2 * (roughness + 0.5) ))*specColor //specColor 为 (1,1,1)，所以我没直接写出来
           half ApproximateVF(half3 L, half3 H,half roughness)
           {
                half LH = saturate(dot(L,H));
                half denom =max(0.1h,(LH * LH) * (roughness + 0.5));//max 防止除0
                return 1/denom;
           }


            half3 LightingURPPBR(half3 albedo, half3 lightColor, half3 lightDirWS, half3 normalWS, half3 viewDirWS,half metallic,half perceptualRoughness)
            {
                //准备各项参数
                half3 H = SafeNormalize(lightDirWS + viewDirWS);
                half NL = saturate(dot(normalWS,lightDirWS));
                
                half roughness = max(perceptualRoughness * perceptualRoughness, HALF_MIN_SQRT);

                half3 dielectricSpec = 0.04; 
                half oneMinusReflectivity = OneMinusReflectivityMetallic(metallic);
                half reflectivity = 1.0 - oneMinusReflectivity;

                half3 brdfSpecular = lerp(dielectricSpec, albedo, metallic);

                half D = D_GGX_TR(normalWS,H,roughness);
                half VF = ApproximateVF(lightDirWS,H,roughness);

                half nominator = D * VF;
                half denominator = 4;
                half3 specularTerm = nominator / denominator * brdfSpecular;

                half3 diffuseTerm = albedo * oneMinusReflectivity / PI;
                half3 radiance = lightColor * NL;

                half3 brdf = PI * (diffuseTerm + specularTerm) * radiance;

                half3 ambientColor = unity_AmbientSky.rgb * albedo;

                return brdf + ambientColor;
            }

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                float3 positionWS = TransformObjectToWorld(IN.positionOS.xyz);
                OUT.positionHCS = TransformWorldToHClip(positionWS);
                OUT.normalWS = TransformObjectToWorldNormal(IN.normalOS,true);
                OUT.viewWS = GetWorldSpaceNormalizeViewDir(positionWS);
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                Light light = GetMainLight();
                half3 lightColor = light.color * light.distanceAttenuation;
                half3 normalWS = normalize(IN.normalWS);
                half3 viewWS = SafeNormalize(IN.viewWS);

                half3 pbr = LightingURPPBR(_Albedo,lightColor,light.direction,normalWS,viewWS,_Metallic,_Roughness);

                half4 totalColor=half4(pbr.rgb,1);

                return totalColor;

            }

            ENDHLSL
        }
    }
}
