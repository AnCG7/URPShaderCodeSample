/*
    *系统说明看SimpleDecalProjector.cs
    *负责贴花的具体裁剪、投影、混合、光照计算等
    *
*/
Shader "Lakehani/URP/Effect/SimpleDecal"
{
    Properties
    {
        _MainTex("Albedo", 2D) = "white" {}
        _BaseColor("Base Color", Color) = (1, 1, 1, 1)
        [Normal][NoScaleOffset]_NormalTex("Normal Map", 2D) = "bump" {}
        _NormalScale("Normal Scale", Range(0, 2)) = 1.0
        _NormalBlend("Normal Blend", Range(0, 1)) = 0.5
        _DecalScale("Decal Scale", Float) = 1.0
        _ProjectionDir("Projection Dir", Vector) = (0, 0, 1, 0)
        _ClipAngleThreshold("Angle Threshold", Float) = 0
        _ClipBoxLocalMin("Clip Box Local Min", Vector) = (0, 0, 0, 0)
        _ClipBoxLocalMax("Clip Box Local Max", Vector) = (1, 1, 1, 0)
        _DecalRenderingLayerMask("Decal Rendering Layer Mask", Float) = 1
        _Specular("Specular", Color) = (1, 1, 1, 1)
        _Smoothness("Smoothness", Range(0.01, 100)) = 10
    }

    SubShader
    {
        Tags { "RenderPipeline" = "UniversalRenderPipeline" }
        ZWrite Off
        ZTest LEqual
        Blend SrcAlpha OneMinusSrcAlpha
        Pass
        {
            Name "SimpleDecalPass"
            Tags { "LightMode" = "UniversalForward" }

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_instancing

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareNormalsTexture.hlsl"
            //#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareRenderingLayerTexture.hlsl"//方便学习，使用自定义RT而不是Unity默认的

            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 worldPos : TEXCOORD1;
                float3 viewDir : TEXCOORD2;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);
            TEXTURE2D(_NormalTex);
            SAMPLER(sampler_NormalTex);
            TEXTURE2D_X_FLOAT(_SimpleDecalRenderingLayersTexture); //一个自定义的全局RT用来存储渲染层信息，在SimpleDecalPreRenderPass中被放入
            SAMPLER(sampler_SimpleDecalRenderingLayersTexture);
            
            CBUFFER_START(UnityPerMaterial)
                float4 _MainTex_ST;
                float4 _BaseColor;
                float _NormalScale;
                float _DecalScale;
                float3 _ProjectionDir;
                float _ClipAngleThreshold;
                float3 _ClipBoxLocalMin;
                float3 _ClipBoxLocalMax;
                float4x4 _DecalWToLMatrix;
                float4x4 _NormalToWorldMatrix;
                float4 _Specular;
                float _NormalBlend;
                float _Smoothness;
                float _DecalRenderingLayerMask;
            CBUFFER_END

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                UNITY_SETUP_INSTANCE_ID(IN);
                UNITY_TRANSFER_INSTANCE_ID(IN, OUT);

                VertexPositionInputs vertexInput = GetVertexPositionInputs(IN.positionOS.xyz);
                OUT.positionHCS = vertexInput.positionCS;
                OUT.worldPos = vertexInput.positionWS;
                OUT.viewDir = GetCameraPositionWS() - vertexInput.positionWS;
                OUT.uv = IN.uv;
                return OUT;
            }

            //参考DeclareRenderingLayerTexture.hlsl的实现
            uint SampleSceneRenderingLayer(float2 uv)
            {
                float renderingLayer = SAMPLE_TEXTURE2D_X(_SimpleDecalRenderingLayersTexture, sampler_SimpleDecalRenderingLayersTexture, UnityStereoTransformScreenSpaceTex(uv)).r;
                return DecodeMeshRenderingLayer(renderingLayer);
            }
            half4 frag(Varyings IN) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(IN);
                
                float2 screenUV = IN.positionHCS.xy / _ScreenParams.xy;

                //判断是否在渲染层范围内
                uint renderingLayer = SampleSceneRenderingLayer(screenUV);
                uint projectorRenderingLayer = uint(_DecalRenderingLayerMask);
                clip((renderingLayer & projectorRenderingLayer) - 0.1);

                //通过深度值计算世界坐标
                float depth = SampleSceneDepth(screenUV);
                float3 worldPos = ComputeWorldSpacePosition(screenUV, depth, UNITY_MATRIX_I_VP);
                float4 localPos = mul(_DecalWToLMatrix, float4(worldPos, 1.0));

                //判断是否在box范围内
                half3 axisMask = step(_ClipBoxLocalMin, localPos.xyz) * step(localPos.xyz, _ClipBoxLocalMax);
                half inBounds = axisMask.x * axisMask.y * axisMask.z;
                clip(inBounds - 0.5);
                
                //这里也可以通过深度值重建世界空间法线，我在SSAO.hlsl中找到了实现，在ReconstructNormal函数，这里方便查看我将注释复制过来
                //基本原理是根据相邻深度值还原到世界坐标，然后通过构建切线和副切线叉乘来计算法线
                // Try reconstructing normal accurately from depth buffer.
                // Low:    DDX/DDY on the current pixel
                // Medium: 3 taps on each direction | x | * | y |
                // High:   5 taps on each direction: | z | x | * | y | w |
                // https://atyuwen.github.io/posts/normal-reconstruction/
                // https://wickedengine.net/2019/09/22/improved-normal-reconstruction-from-depth/
                //也可以在ShaderPassDecal.hlsl的宏DECAL_RECONSTRUCT_NORMAL下面看到unity的decal关于重建法线的实现
                
                //这里我直接使用了法线buffer，没有通过深度值重建，但是默认没有改法线纹理的，记得在配置文件和SimpleDecalRenderPass中开启
                float3 worldNormal  = SampleSceneNormals(screenUV);
                float clipAngleThreshold = _ClipAngleThreshold;//防止卡0度或90度临界，稍微增大一点
                float cosAngle = dot(worldNormal, normalize(-_ProjectionDir));
                float cosThreshold = cos(clipAngleThreshold);
                clip(cosAngle - cosThreshold);
                
                
                //为了方便控制贴图缩放，这里看个人需求，我这里以中心为轴点缩放
                float2 scalePos = localPos.xy * _DecalScale;
                //需要计算要投影的贴图的uv，已经知道box内的局部坐标了而投影方向是确定的朝局部z轴方向，将局部坐标xy的比例计算出来作为uv就行了
                float2 texUV = (scalePos - _ClipBoxLocalMin.xy) / (_ClipBoxLocalMax.xy - _ClipBoxLocalMin.xy);
                texUV = TRANSFORM_TEX(texUV, _MainTex);
                half4 albedo = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, texUV);
                albedo *= _BaseColor;

                //正常采样法线贴图
                float3 normalTS = UnpackNormalScale(SAMPLE_TEXTURE2D(_NormalTex, sampler_NormalTex, texUV), _NormalScale);
                //但是法线是切线空间的需要转到世界空间，_NormalToWorldMatrix是C#传递过来的
                float3 normalWS = TransformTangentToWorld(normalTS,_NormalToWorldMatrix);
                normalWS = normalize(normalWS);
                
                //这里可以使用lerp混合2条世界空间的法线
                normalWS.xyz = normalize(lerp(normalWS.xyz, worldNormal.xyz, _NormalBlend));
                
                
                Light mainLight = GetMainLight();
                float3 lightDir = mainLight.direction;
                float3 lightColor = mainLight.color;
                
                float diff = saturate(dot(normalWS, lightDir));
                float3 diffuse = diff * lightColor;
                
                float3 viewDir = GetWorldSpaceNormalizeViewDir(worldPos);
                
                //使用 LightingSpecular 函数计算高光
                half3 specular = LightingSpecular(half3(lightColor), half3(lightDir), half3(normalWS), half3(viewDir), _Specular, _Smoothness);
                
                float3 lighting = diffuse + float3(specular);
                
                albedo.rgb *= lighting;
                
                return half4(albedo.rgb, albedo.a);
            }
            ENDHLSL
        }
    }
}