/* 
折射和物理上没啥区别，实现的时候就是偏移uv，使后面的物体看起来发生偏移
因为折射的是后面的物体，所以我们需要一张额外的纹理来采样，它可以是一张普通纹理，一个反射探针的纹理，一个单独渲染在RenderTexture的纹理。
想象一下水，【水面】是一个模型，【水下面的地面】又是一个模型，我们想透过水面看下面的地面，我们的需要一张【水下面的地面】的纹理
然后在【水面】这个模型上，采样【水下面的地面】的纹理，并偏移这个纹理，就能看到折射的效果

我这里直接使用URP自带的_CameraOpaqueTexture来采样，这个纹理会把不透明物体渲染上去（仅不透明）
注意：要使用_CameraOpaqueTexture，记得Scriptable Render Pipeline Settings 中的 Opaque Texture 要打开
所以我这里在Transparent队列，可以拿到渲染好的不透明物体，来做一个透镜的演示

总结：
使用自带URP自带的_CameraOpaqueTexture，仅不透明物体会渲染上去
使用反射探针的纹理
使用单独渲染的纹理（可以用RanderFeature或者RenderTexture，可以包含透明物体，可以自定义，灵活性较高）
使用普通的纹理贴图（例如做放大镜）
使用屏幕后处理
*/

Shader "Lakehani/URP/Lighting/Refraction"
{
    Properties
    {
        _Intensity ("Intensity",  Float) = 1.0
    }
    SubShader
    {
        Tags { "RenderType"="Transparent" "RenderPipeline"="UniversalRenderPipeline" "Queue"="Transparent"}

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

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
            float _Intensity;
            CBUFFER_END

            //内置变量---------------------- 参考 DeclareOpaqueTexture.hlsl
            TEXTURE2D(_CameraOpaqueTexture);
            SAMPLER(sampler_CameraOpaqueTexture);
            //----------------------

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                float3 positionWS = TransformObjectToWorld(IN.positionOS.xyz);
                OUT.positionHCS = TransformWorldToHClip(positionWS);
                OUT.normalWS = TransformObjectToWorldNormal(IN.normalOS);
                OUT.viewWS = GetWorldSpaceViewDir(positionWS);

                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                half3 normalWS = normalize(IN.normalWS);
                half3 viewWS = normalize(IN.viewWS);
                //点的屏幕坐标
                half2 screenUV = IN.positionHCS.xy/_ScreenParams.xy;
                //比例：因为视角和法线点乘范围[-1,1]，所以ratio正好是一个从0到1再到0的弧形形状（画个图就容易理解了，正好是凸起的）
                half ratio = (1 - pow(dot(normalWS,viewWS),2.0)) * _Intensity;
                //我们要偏移还需要一个方向，让方向乘以比例。把法线方向转到视角空间，沿法线方向偏移，我们只要xy不需要z
                float3 refractionOffset = _Intensity * TransformWorldToViewDir(normalWS) * ratio;
                //使用偏移后的uv的采样
                half4 col = SAMPLE_TEXTURE2D(_CameraOpaqueTexture ,sampler_CameraOpaqueTexture, screenUV + refractionOffset.xy);
                
                return col;
            }

            ENDHLSL
        }
    }
}
