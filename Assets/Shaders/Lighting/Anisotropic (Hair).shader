/*
物理上的各向异性解释我无法直接和图形这边的现象联想在一起，所以寻找了在图形渲染中比较贴切的解释。
各项异性表面从表面上细致的纹理、槽或丝缕来获得它特有的外观，比如拉丝金属、CD的闪光面。
当使用普通的材质进行光照时，计算仅考虑表面的法线向量、到光源的向量、及到相机的向量。
但是对于各向异性表面，没有真正可以使用的连续的法线向量，因为每个丝缕或槽都有各种不同的法线方向，法线方向和槽的方向垂直。
其实在渲染中来实现各向异性光照时，并不是让每一个顶点在不同的方向都拥有不同的法线信息，它的计算是基于片元着色器的；
如果是各项同性，我们只需要通过插值得到各个片元的法线信息即可，而对于各向异性来说，我们需要在片远着色器中根据法线扰动规则重新计算法线。
这样虽然看起来是一个平面，但它上面的像素却会因为法线扰动而形成一些纹理、凹槽的效果，从而展示出更多的细节表现，
而且，法线的扰动通常是有规律的，所以在不同的方向上，表现出的效果可能会不一样，从而表现出所谓的光学各向异性。
这个法线扰动规则可以是一个公式，也可以是一张纹理

各向异性使用头发渲染的常见算法Kajiya-Kay来演示,
为方便观察各项异性高光，所以并没有完整的去实现Kajiya-Kay模型，完整的可以参考 http://web.engr.oregonstate.edu/~mjb/cs519/Projects/Papers/HairRendering.pdf
*/

Shader "Lakehani/URP/Lighting/Anisotropic"
{
    Properties
    {
        _SpecularColor ("SpecularColor", Color) = (1,1,1,1)
        _SpecularExp ("SpecularExp",  float) = 2
        _StretchedNoise("StretchedNoise", 2D) = "white" {}
        _Shift("Shift",float) = 0
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
                float4 tangentOS : TANGENT;
                float2 texcoord  : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionHCS  : SV_POSITION;
                float3 normalWS : TEXCOORD0;
                float3 bitangentWS : TEXCOORD1; 
                float3 viewWS : TEXCOORD2;
                float2 texcoord  : TEXCOORD3;
            };

            CBUFFER_START(UnityPerMaterial)
            half4 _SpecularColor;
            float4 _StretchedNoise_ST;
            half _SpecularExp;
            half _Shift;
            CBUFFER_END
            TEXTURE2D(_StretchedNoise);SAMPLER(sampler_StretchedNoise);

            //注意是副切线不是切线，也就是切线空间 TBN 中的 B
            half3 ShiftTangent(half3 bitangentWS,half3 normalWS,half shift)
            {
                half3 shiftedT = bitangentWS + shift * normalWS;
                return normalize(shiftedT);
            }

            half StrandSpecular(half3 bitangentWS,half3 viewDirWS,half3 lightDirWS,half exponent)
            {
                half3 H = normalize(lightDirWS + viewDirWS);
                half dotTH = dot(bitangentWS,H); // 点乘 计算出来的是2个单位向量的cos的值
                half sinTH = sqrt(1.0 - dotTH * dotTH);//因为 sin^2 + cos^2 = 1 所以 sin = sqrt(1 - cos^2);
                half dirAttenuation = smoothstep(-1.0,0.0,dotTH);
                return dirAttenuation * pow(sinTH,exponent);
            }

            half3 LightingHair(half3 bitangentWS, half3 lightDirWS, half3 normalWS, half3 viewDirWS, float2 uv,half exp,half3 specular)
            {
                //shift tangents
                half shiftTex = SAMPLE_TEXTURE2D(_StretchedNoise, sampler_StretchedNoise, uv).r - 0.5;
                half3 t1 = ShiftTangent(bitangentWS,normalWS,_Shift + shiftTex);

                //specular
                half3 specularColor  = StrandSpecular(t1,viewDirWS,lightDirWS,exp) * specular;

                return specularColor;

            }

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                VertexNormalInputs normalInput = GetVertexNormalInputs(IN.normalOS, IN.tangentOS);//GetVertexNormalInputs定义在ShaderVariablesFunctions.hlsl中
                float3 positionWS = TransformObjectToWorld(IN.positionOS.xyz);
                OUT.positionHCS = TransformWorldToHClip(positionWS);
                OUT.normalWS = normalInput.normalWS;
                OUT.bitangentWS = normalInput.bitangentWS;
                OUT.viewWS = GetWorldSpaceViewDir(positionWS);
                OUT.texcoord = TRANSFORM_TEX(IN.texcoord, _StretchedNoise);
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                Light light = GetMainLight();
                half3 normalWS = normalize(IN.normalWS);
                half3 viewWS = SafeNormalize(IN.viewWS);
                half3 bitangentWS = normalize(IN.bitangentWS);

                half3 hairColor = LightingHair(bitangentWS,light.direction,normalWS,viewWS,IN.texcoord,_SpecularExp,_SpecularColor.rgb);

                half4 totalColor=half4(hairColor.rgb,1);

                return totalColor;

            }

            ENDHLSL
        }
    }
}
